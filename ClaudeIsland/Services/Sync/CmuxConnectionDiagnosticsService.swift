//
//  CmuxConnectionDiagnosticsService.swift
//  ClaudeIsland
//
//  Non-blocking diagnostics for Settings → cmux Connection.
//

import AppKit
import ApplicationServices
import Darwin
import Foundation

// MARK: - Public API

struct CmuxConnectionSnapshot: Sendable, Equatable {
    struct TestTarget: Sendable, Equatable {
        let workspaceId: String
        let surfaceId: String?
    }

    let cmuxBinaryInstalled: Bool
    let accessibilityGranted: Bool
    let claudeSessionCount: Int
    let automationGranted: Bool?
    let automationDetail: String
    let testTarget: TestTarget?
}

protocol CmuxConnectionDiagnosticsServing {
    func loadSnapshot() async throws -> CmuxConnectionSnapshot
    func requestAutomationPermission() async -> (ok: Bool, detail: String)
    func sendDiagnosticProbe() async -> (ok: Bool, detail: String)
}

final class CmuxConnectionDiagnosticsService: CmuxConnectionDiagnosticsServing {

    func loadSnapshot() async throws -> CmuxConnectionSnapshot {
        try Task.checkCancellation()

        async let cmuxOk: Bool = Self.isCmuxBinaryInstalled()
        async let axOk: Bool = Self.isAccessibilityGranted()
        let claudePids = try await Self.listClaudePidsAsync()

        try Task.checkCancellation()
        let target = try await Self.findFirstCmuxTarget(in: claudePids)

        try Task.checkCancellation()
        let (autoGranted, autoDetail) = await MainActor.run {
            Self.probeAutomationPermissionMainActor()
        }

        try Task.checkCancellation()
        return CmuxConnectionSnapshot(
            cmuxBinaryInstalled: await cmuxOk,
            accessibilityGranted: await axOk,
            claudeSessionCount: claudePids.count,
            automationGranted: autoGranted,
            automationDetail: autoDetail,
            testTarget: target
        )
    }

    func requestAutomationPermission() async -> (ok: Bool, detail: String) {
        await MainActor.run {
            Self.requestAutomationPermissionMainActor()
        }
    }

    func sendDiagnosticProbe() async -> (ok: Bool, detail: String) {
        do {
            let snapshot = try await loadSnapshot()
            guard snapshot.cmuxBinaryInstalled else {
                return (false, L10n.cmuxBinaryMissing)
            }
            guard let target = snapshot.testTarget else {
                return (false, L10n.testSendNoTarget)
            }

            try Task.checkCancellation()
            return try await Self.runOffMain {
                var args = ["send", "--workspace", target.workspaceId]
                if let surfId = target.surfaceId {
                    args += ["--surface", surfId]
                }
                args += ["--", "# CodeIsland probe\r"]

                let (_, ok) = Self.runShellWithTimeout(Self.cmuxPath, args, timeout: 5.0)
                if ok {
                    return (true, "\(L10n.testSendSuccess) — ws=\(target.workspaceId.prefix(8)) surf=\(target.surfaceId?.prefix(8).description ?? "-")")
                }
                return (false, L10n.testSendFailed)
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }
}

// MARK: - Implementation

extension CmuxConnectionDiagnosticsService {
    private static let cmuxPath = "/Applications/cmux.app/Contents/Resources/bin/cmux"

    private static func runOffMain<T: Sendable>(
        _ work: @Sendable @escaping () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    cont.resume(returning: try work())
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    /// Spawn a subprocess, capture stdout, and SIGKILL it if it exceeds `timeout`.
    /// Returns `(stdout, success)`.
    private static func runShellWithTimeout(
        _ executable: String,
        _ arguments: [String],
        timeout: TimeInterval,
        terminationGrace: TimeInterval = 0.25
    ) -> (output: String?, success: Bool) {
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice

        do {
            try p.run()
        } catch {
            return (nil, false)
        }

        // Watchdog: SIGTERM at `timeout`, SIGKILL at `timeout + grace` if still alive.
        let watchdog = DispatchWorkItem { [p] in
            guard p.isRunning else { return }
            p.terminate()
            Thread.sleep(forTimeInterval: terminationGrace)
            if p.isRunning {
                kill(p.processIdentifier, SIGKILL)
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: watchdog)

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        watchdog.cancel()

        let output = String(data: data, encoding: .utf8)
        let success = p.terminationStatus == 0
        return (output, success)
    }

    private static func listClaudePids() -> [Int] {
        let fromConfig = discoverClaudePidsFromConfig()
        if !fromConfig.isEmpty { return fromConfig }
        return listClaudePidsFromPs()
    }

    private static func discoverClaudePidsFromConfig() -> [Int] {
        let sessionsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/sessions")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: nil) else {
            return []
        }

        var pids: [Int] = []
        for url in contents where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pid = json["pid"] as? Int,
                  let sessionId = json["sessionId"] as? String,
                  isUuidLike(sessionId) else { continue }

            let (out, ok) = runShellWithTimeout("/bin/ps", ["-p", "\(pid)", "-o", "pid="], timeout: 1.0)
            guard ok,
                  let line = out?.trimmingCharacters(in: .whitespacesAndNewlines),
                  line == "\(pid)" else { continue }

            pids.append(pid)
        }
        return pids
    }

    private static func listClaudePidsFromPs() -> [Int] {
        let (out, ok) = runShellWithTimeout("/bin/ps", ["-Axww", "-o", "pid=,command="], timeout: 3.0)
        guard ok, let text = out else { return [] }

        var result: [Int] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("/claude") || trimmed.contains(" claude ") else { continue }
            let firstSpace = trimmed.firstIndex(of: " ") ?? trimmed.endIndex
            let pidStr = String(trimmed[..<firstSpace])
            if let pid = Int(pidStr) {
                result.append(pid)
            }
        }
        return Array(Set(result))
    }

    private static func readCmuxIDs(forPid pid: Int) -> (workspaceId: String, surfaceId: String?)? {
        let (out, ok) = runShellWithTimeout("/bin/ps", ["-Eww", "-p", "\(pid)", "-o", "command="], timeout: 2.0)
        guard ok, let envLine = out else { return nil }

        var wsId: String?
        var surfId: String?
        for token in envLine.split(separator: " ") {
            if token.hasPrefix("CMUX_WORKSPACE_ID=") {
                wsId = String(token.dropFirst("CMUX_WORKSPACE_ID=".count))
            } else if token.hasPrefix("CMUX_SURFACE_ID=") {
                surfId = String(token.dropFirst("CMUX_SURFACE_ID=".count))
            }
        }
        guard let wsId else { return nil }
        return (wsId, surfId)
    }

    private static func isCmuxBinaryInstalled() async -> Bool {
        (try? await runOffMain {
            FileManager.default.isExecutableFile(atPath: cmuxPath)
        }) ?? false
    }

    private static func isAccessibilityGranted() async -> Bool {
        (try? await runOffMain {
            AXIsProcessTrusted()
        }) ?? false
    }

    private static func listClaudePidsAsync() async throws -> [Int] {
        try Task.checkCancellation()
        return try await runOffMain {
            listClaudePids()
        }
    }

    private static func readCmuxIDsAsync(forPid pid: Int) async throws -> (workspaceId: String, surfaceId: String?)? {
        try Task.checkCancellation()
        return try await runOffMain {
            readCmuxIDs(forPid: pid)
        }
    }

    private static func findFirstCmuxTarget(in pids: [Int]) async throws -> CmuxConnectionSnapshot.TestTarget? {
        for pid in pids {
            try Task.checkCancellation()
            if let ids = try await readCmuxIDsAsync(forPid: pid) {
                return .init(workspaceId: ids.workspaceId, surfaceId: ids.surfaceId)
            }
        }
        return nil
    }

    private static func isUuidLike(_ s: String) -> Bool {
        // 8-4-4-4-12
        guard s.count == 36 else { return false }
        let parts = s.split(separator: "-")
        guard parts.count == 5 else { return false }
        let sizes = parts.map(\.count)
        guard sizes == [8, 4, 4, 4, 12] else { return false }
        return s.unicodeScalars.allSatisfy { scalar in
            scalar == "-" || ("0"..."9").contains(scalar) || ("a"..."f").contains(scalar) || ("A"..."F").contains(scalar)
        }
    }

    /// Non-invasive probe for Automation (AppleEvents) TCC permission.
    /// Uses `askUserIfNeeded: false` so it never triggers the permission prompt.
    @MainActor
    private static func probeAutomationPermissionMainActor() -> (granted: Bool?, detail: String) {
        let candidates: [(bundleId: String, label: String)] = [
            ("com.cmuxterm.app", "cmux"),
            ("com.googlecode.iterm2", "iTerm"),
            ("com.mitchellh.ghostty", "Ghostty"),
            ("com.apple.Terminal", "Terminal")
        ]

        for (bundleId, label) in candidates {
            guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty else { continue }

            var targetAddr = AEAddressDesc()
            let targetData = Data(bundleId.utf8)
            let createStatus: OSErr = targetData.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return OSErr(-1) }
                return AECreateDesc(
                    DescType(typeApplicationBundleID),
                    baseAddress,
                    bytes.count,
                    &targetAddr
                )
            }
            guard createStatus == OSErr(noErr) else {
                return (nil, "\(label) — AECreateDesc err=\(createStatus)")
            }
            defer { AEDisposeDesc(&targetAddr) }

            let status = AEDeterminePermissionToAutomateTarget(
                &targetAddr,
                AEEventClass(typeWildCard),
                AEEventID(typeWildCard),
                false
            )
            switch status {
            case noErr:
                return (true, "\(label) ✓")
            case OSStatus(errAEEventNotPermitted):
                return (false, "\(label) — denied (err=-1743)")
            case -1744: // errAEEventWouldRequireUserConsent
                return (nil, "\(label) — not yet prompted")
            default:
                return (nil, "\(label) — status=\(status)")
            }
        }
        return (nil, L10n.automationUnknown)
    }

    @MainActor
    private static func requestAutomationPermissionMainActor() -> (ok: Bool, detail: String) {
        let candidates: [(bundleId: String, label: String)] = [
            ("com.cmuxterm.app", "cmux"),
            ("com.googlecode.iterm2", "iTerm"),
            ("com.mitchellh.ghostty", "Ghostty"),
            ("com.apple.Terminal", "Terminal")
        ]

        for (bundleId, label) in candidates {
            guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty else { continue }

            let source = "tell application id \"\(bundleId)\" to activate"
            let script = NSAppleScript(source: source)
            var errorInfo: NSDictionary?
            _ = script?.executeAndReturnError(&errorInfo)

            if errorInfo == nil {
                return (true, "\(L10n.requestAutomationPrompted) (\(label))")
            }

            let errNum = (errorInfo?["NSAppleScriptErrorNumber"] as? Int) ?? 0
            let errMsg = (errorInfo?["NSAppleScriptErrorMessage"] as? String) ?? "?"
            return (false, "\(L10n.requestAutomationDenied) (\(label) · err=\(errNum) · \(errMsg))")
        }

        return (false, L10n.requestAutomationNoTerminal)
    }
}
