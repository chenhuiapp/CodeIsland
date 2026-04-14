//
//  CmuxConnectionViewModelTests.swift
//  ClaudeIslandTests
//
//  View-model tests for Settings → cmux Connection diagnostics.
//

import XCTest
@testable import ClaudeIsland

final class CmuxConnectionViewModelTests: XCTestCase {

    private actor MockService: CmuxConnectionDiagnosticsServing {
        enum MockError: Error { case boom }

        struct PendingCall {
            let snapshotContinuation: CheckedContinuation<CmuxConnectionSnapshot, Error>
        }

        struct PendingWaiter {
            let desiredCount: Int
            let continuation: CheckedContinuation<Void, Never>
        }

        private(set) var loadSnapshotCallCount = 0
        private var pending: [PendingCall] = []
        private var waiters: [PendingWaiter] = []
        var nextAutomationResult: (ok: Bool, detail: String) = (true, "ok")
        var nextProbeResult: (ok: Bool, detail: String) = (true, "ok")
        var loadSnapshotError: Error?

        func loadSnapshot() async throws -> CmuxConnectionSnapshot {
            loadSnapshotCallCount += 1
            if let loadSnapshotError { throw loadSnapshotError }
            return try await withCheckedThrowingContinuation { cont in
                pending.append(PendingCall(snapshotContinuation: cont))
                flushWaitersIfReady()
            }
        }

        func getLoadSnapshotCallCount() -> Int { loadSnapshotCallCount }

        func setLoadSnapshotError(_ error: Error?) {
            loadSnapshotError = error
        }

        func waitForPendingSnapshotCount(_ desiredCount: Int) async {
            if pending.count >= desiredCount { return }
            await withCheckedContinuation { cont in
                waiters.append(PendingWaiter(desiredCount: desiredCount, continuation: cont))
            }
        }

        func completeNextSnapshot(_ snapshot: CmuxConnectionSnapshot) {
            guard !pending.isEmpty else { return }
            let call = pending.removeFirst()
            call.snapshotContinuation.resume(returning: snapshot)
        }

        func failNextSnapshot(_ error: Error) {
            guard !pending.isEmpty else { return }
            let call = pending.removeFirst()
            call.snapshotContinuation.resume(throwing: error)
        }

        private func flushWaitersIfReady() {
            guard !waiters.isEmpty else { return }
            let ready = waiters.enumerated().filter { pending.count >= $0.element.desiredCount }.map(\.offset)
            guard !ready.isEmpty else { return }
            // Remove from back to front so indices remain valid.
            for idx in ready.sorted(by: >) {
                let w = waiters.remove(at: idx)
                w.continuation.resume()
            }
        }

        func requestAutomationPermission() async -> (ok: Bool, detail: String) {
            nextAutomationResult
        }

        func sendDiagnosticProbe() async -> (ok: Bool, detail: String) {
            nextProbeResult
        }
    }

    private func awaitEventually(
        timeout: TimeInterval = 1.0,
        _ predicate: @escaping @MainActor () -> Bool
    ) async {
        let exp = expectation(description: "awaitEventually")
        Task { @MainActor in
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if predicate() {
                    exp.fulfill()
                    return
                }
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
        await fulfillment(of: [exp], timeout: timeout + 0.25)
    }

    func test_loadIfNeeded_transitions_immediately_to_loading() async {
        let service = MockService()
        let vm = await MainActor.run { CmuxConnectionViewModel(service: service) }

        await MainActor.run {
            XCTAssertEqual(vm.state, .idle)
        }

        await vm.loadIfNeeded()

        await MainActor.run {
            guard case .loading(previous: nil) = vm.state else {
                XCTFail("expected .loading(previous: nil), got \(vm.state)")
                return
            }
        }
    }

    func test_loadIfNeeded_publishes_loaded_snapshot_from_service() async {
        let service = MockService()
        let vm = await MainActor.run { CmuxConnectionViewModel(service: service) }

        await vm.loadIfNeeded()
        await service.waitForPendingSnapshotCount(1)

        let snapshot = CmuxConnectionSnapshot(
            cmuxBinaryInstalled: true,
            accessibilityGranted: true,
            claudeSessionCount: 2,
            automationGranted: nil,
            automationDetail: "not yet prompted",
            testTarget: .init(workspaceId: "ws", surfaceId: "surf")
        )
        await service.completeNextSnapshot(snapshot)

        await awaitEventually {
            if case .loaded = vm.state { return true }
            return false
        }

        await MainActor.run {
            XCTAssertEqual(vm.state, .loaded(snapshot))
        }
    }

    func test_refresh_cancels_inFlight_and_applies_latest_snapshot_only() async {
        let service = MockService()
        let vm = await MainActor.run { CmuxConnectionViewModel(service: service) }

        await vm.refresh()
        await service.waitForPendingSnapshotCount(1)
        await MainActor.run {
            guard case .loading(previous: nil) = vm.state else {
                XCTFail("expected .loading(previous: nil), got \(vm.state)")
                return
            }
        }
        XCTAssertEqual(await service.getLoadSnapshotCallCount(), 1)

        await vm.refresh()
        await service.waitForPendingSnapshotCount(2)
        XCTAssertEqual(await service.getLoadSnapshotCallCount(), 2)

        let snapshot1 = CmuxConnectionSnapshot(
            cmuxBinaryInstalled: false,
            accessibilityGranted: false,
            claudeSessionCount: 0,
            automationGranted: nil,
            automationDetail: "old",
            testTarget: nil
        )
        let snapshot2 = CmuxConnectionSnapshot(
            cmuxBinaryInstalled: true,
            accessibilityGranted: true,
            claudeSessionCount: 1,
            automationGranted: true,
            automationDetail: "new",
            testTarget: nil
        )

        // Complete the older request first; it should be ignored.
        await service.completeNextSnapshot(snapshot1)
        // Complete the latest request; it should win.
        await service.completeNextSnapshot(snapshot2)

        await awaitEventually {
            vm.state == .loaded(snapshot2)
        }

        await MainActor.run {
            XCTAssertEqual(vm.state, .loaded(snapshot2))
        }
    }

    func test_failedProbe_surfaces_error_state_instead_of_hanging() async {
        let service = MockService()
        await service.setLoadSnapshotError(MockService.MockError.boom)
        let vm = await MainActor.run { CmuxConnectionViewModel(service: service) }

        await vm.refresh()

        await awaitEventually {
            if case .error = vm.state { return true }
            return false
        }

        await MainActor.run {
            if case .error(message: let message, previous: _) = vm.state {
                XCTAssertFalse(message.isEmpty)
            } else {
                XCTFail("expected error state, got \(vm.state)")
            }
        }
    }

    func test_refresh_retains_previous_snapshot_while_loading_replacement() async {
        let service = MockService()
        let vm = await MainActor.run { CmuxConnectionViewModel(service: service) }

        let snapshot1 = CmuxConnectionSnapshot(
            cmuxBinaryInstalled: true,
            accessibilityGranted: true,
            claudeSessionCount: 1,
            automationGranted: nil,
            automationDetail: "first",
            testTarget: nil
        )
        let snapshot2 = CmuxConnectionSnapshot(
            cmuxBinaryInstalled: false,
            accessibilityGranted: false,
            claudeSessionCount: 0,
            automationGranted: false,
            automationDetail: "second",
            testTarget: nil
        )

        await vm.refresh()
        await service.waitForPendingSnapshotCount(1)
        await service.completeNextSnapshot(snapshot1)

        await awaitEventually {
            vm.state == .loaded(snapshot1)
        }

        await vm.refresh()
        await service.waitForPendingSnapshotCount(1)

        await MainActor.run {
            guard case .loading(previous: let prev?) = vm.state else {
                XCTFail("expected .loading(previous: snapshot1), got \(vm.state)")
                return
            }
            XCTAssertEqual(prev, snapshot1)
            XCTAssertEqual(vm.snapshot, snapshot1)
        }

        await service.completeNextSnapshot(snapshot2)

        await awaitEventually {
            vm.state == .loaded(snapshot2)
        }

        await MainActor.run {
            XCTAssertEqual(vm.state, .loaded(snapshot2))
        }
    }
}
