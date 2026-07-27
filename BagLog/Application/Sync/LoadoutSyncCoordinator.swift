import Foundation
import Observation
import Persistence
import Services

enum LoadoutSyncPresentationState: Equatable {
    case disabled
    case idle
    case needsProfile
    case profileConflict
    case signedOut
    case syncing
    case waitingToRetry
    case failed
}

@MainActor
@Observable
final class LoadoutSyncCoordinator {
    private(set) var state = LoadoutSyncPresentationState.disabled
    private(set) var triggerRevision = 0
    private(set) var dataRevision = 0

    private let configuration: LoadoutSyncConfiguration
    private let engine: LoadoutSyncEngine
    private let persistence: any BagLogSyncPersisting
    private var shouldRetryFailures = false

    init(
        configuration: LoadoutSyncConfiguration,
        engine: LoadoutSyncEngine,
        persistence: any BagLogSyncPersisting
    ) {
        self.configuration = configuration
        self.engine = engine
        self.persistence = persistence
        state = configuration.isEnabled ? .signedOut : .disabled
    }

    func trigger() {
        triggerRevision += 1
    }

    func retry() {
        shouldRetryFailures = true
        trigger()
    }

    func synchronize(
        isAuthenticated: Bool,
        isForeground: Bool
    ) async {
        await withTaskCancellationHandler {
            await runCycles(
                isAuthenticated: isAuthenticated,
                isForeground: isForeground
            )
        } onCancel: {
            Task {
                await self.engine.cancel()
            }
        }
    }

    private func runCycles(
        isAuthenticated: Bool,
        isForeground: Bool
    ) async {
        let localProfile = await localProfile(
            whenEligible: isAuthenticated && isForeground
        )
        var retryFailures = shouldRetryFailures
        shouldRetryFailures = false

        while !Task.isCancelled {
            state = cycleStartingState(
                isAuthenticated: isAuthenticated,
                isForeground: isForeground
            )
            let result = await engine.runCycle(
                context: LoadoutSyncRunContext(
                    isFeatureEnabled: configuration.isEnabled,
                    isForeground: isForeground,
                    isAuthenticated: isAuthenticated,
                    localProfile: localProfile,
                    shouldRetryFailures: retryFailures
                )
            )
            retryFailures = false
            guard case let .retryAt(_, date) = result else {
                apply(result)
                return
            }
            state = .waitingToRetry
            guard await wait(until: date) else {
                return
            }
        }
    }

    private func localProfile(
        whenEligible isEligible: Bool
    ) async -> UserProfileSnapshot? {
        guard configuration.isEnabled, isEligible else {
            return nil
        }
        return try? await persistence.localProfile()
    }

    private func cycleStartingState(
        isAuthenticated: Bool,
        isForeground: Bool
    ) -> LoadoutSyncPresentationState {
        guard configuration.isEnabled else {
            return .disabled
        }
        guard isAuthenticated else {
            return .signedOut
        }
        return isForeground ? .syncing : .idle
    }

    private func apply(_ result: LoadoutSyncCycleResult) {
        switch result {
        case .disabled:
            state = .disabled
        case .signedOut:
            state = .signedOut
        case .profileRequired:
            state = .needsProfile
        case .profileConflict:
            state = .profileConflict
        case .idle:
            state = .idle
            dataRevision += 1
        case .retryAt:
            state = .waitingToRetry
        case .failed:
            state = .failed
            dataRevision += 1
        case .cancelled:
            state = .idle
        }
    }

    private func wait(until date: Date) async -> Bool {
        let delay = date.timeIntervalSinceNow
        guard delay > 0 else {
            return true
        }
        do {
            try await Task.sleep(for: .seconds(delay))
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}
