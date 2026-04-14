//
//  CmuxConnectionViewModel.swift
//  ClaudeIsland
//
//  Non-blocking UI state for Settings → cmux Connection.
//

import Foundation
import Combine

@MainActor
final class CmuxConnectionViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case loading(previous: CmuxConnectionSnapshot?)
        case loaded(CmuxConnectionSnapshot)
        case error(message: String, previous: CmuxConnectionSnapshot?)
    }

    enum ActionState: Equatable {
        case idle
        case running
        case done(detail: String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var testAction: ActionState = .idle
    @Published private(set) var automationAction: ActionState = .idle

    private let service: CmuxConnectionDiagnosticsServing

    private var loadTask: Task<Void, Never>?
    private var loadToken: UInt64 = 0

    private var testTask: Task<Void, Never>?
    private var automationTask: Task<Void, Never>?

    init(service: CmuxConnectionDiagnosticsServing = CmuxConnectionDiagnosticsService()) {
        self.service = service
    }

    var snapshot: CmuxConnectionSnapshot? {
        switch state {
        case .loaded(let s): return s
        case .loading(let previous): return previous
        case .error(_, let previous): return previous
        case .idle: return nil
        }
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await refresh()
    }

    func refresh() async {
        startLoad()
    }

    func sendTest() async {
        testTask?.cancel()
        testAction = .running

        let service = self.service
        testTask = Task.detached(priority: .userInitiated) { [weak self] in
            let (_, detail) = await service.sendDiagnosticProbe()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.testAction = .done(detail: detail)
                self.startLoad()
            }
        }
    }

    func requestAutomation() async {
        automationTask?.cancel()
        automationAction = .running

        let service = self.service
        automationTask = Task.detached(priority: .userInitiated) { [weak self] in
            let (_, detail) = await service.requestAutomationPermission()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.automationAction = .done(detail: detail)
                self.startLoad()
            }
        }
    }

    private func startLoad() {
        let previous = snapshot
        loadTask?.cancel()
        loadToken &+= 1
        let token = loadToken

        state = .loading(previous: previous)

        let service = self.service
        loadTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let snapshot = try await service.loadSnapshot()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, token == self.loadToken else { return }
                    self.state = .loaded(snapshot)
                }
            } catch is CancellationError {
                // Caller intentionally replaced in-flight work.
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, token == self.loadToken else { return }
                    self.state = .error(message: error.localizedDescription, previous: previous)
                }
            }
        }
    }
}
