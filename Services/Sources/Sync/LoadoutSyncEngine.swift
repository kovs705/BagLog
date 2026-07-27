import Foundation
import Persistence

public struct LoadoutSyncRunContext: Sendable {
    public let isFeatureEnabled: Bool
    public let isForeground: Bool
    public let isAuthenticated: Bool
    public let localProfile: UserProfileSnapshot?
    public let shouldRetryFailures: Bool

    public init(
        isFeatureEnabled: Bool,
        isForeground: Bool,
        isAuthenticated: Bool,
        localProfile: UserProfileSnapshot?,
        shouldRetryFailures: Bool = false
    ) {
        self.isFeatureEnabled = isFeatureEnabled
        self.isForeground = isForeground
        self.isAuthenticated = isAuthenticated
        self.localProfile = localProfile
        self.shouldRetryFailures = shouldRetryFailures
    }
}

public enum LoadoutSyncCycleResult: Sendable, Equatable {
    case cancelled
    case disabled
    case failed(scopeID: UUID?, code: String)
    case idle(scopeID: UUID)
    case profileConflict
    case profileRequired
    case retryAt(scopeID: UUID, date: Date)
    case signedOut
}

public actor LoadoutSyncEngine {
    private let api: any BagLogLoadoutAPIProviding
    private let persistence: any BagLogSyncPersisting
    private let dependencies: LoadoutSyncEngineDependencies

    private var cycle: (
        id: UUID,
        task: Task<LoadoutSyncCycleResult, Never>
    )?

    public init(
        api: any BagLogLoadoutAPIProviding,
        persistence: any BagLogSyncPersisting,
        dependencies: LoadoutSyncEngineDependencies = .live
    ) {
        self.api = api
        self.persistence = persistence
        self.dependencies = dependencies
    }

    public func runCycle(
        context: LoadoutSyncRunContext
    ) async -> LoadoutSyncCycleResult {
        if let cycle {
            return await cycle.task.value
        }
        let cycleID = UUID()
        let task = Task {
            await self.performCycle(context: context)
        }
        cycle = (cycleID, task)
        let result = await task.value
        if cycle?.id == cycleID {
            cycle = nil
        }
        return result
    }

    public func cancel() {
        cycle?.task.cancel()
        cycle = nil
    }

    private func performCycle(
        context: LoadoutSyncRunContext
    ) async -> LoadoutSyncCycleResult {
        guard context.isFeatureEnabled else {
            await persistence.deactivateSyncScope()
            return .disabled
        }
        guard context.isForeground else {
            await persistence.deactivateSyncScope()
            return .cancelled
        }
        guard context.isAuthenticated else {
            await persistence.deactivateSyncScope()
            return .signedOut
        }
        guard let localProfile = context.localProfile else {
            await persistence.deactivateSyncScope()
            return .profileRequired
        }

        do {
            try Task.checkCancellation()
            let scope = try await prepareScope(localProfile: localProfile)
            if context.shouldRetryFailures {
                try await persistence.retryFailedMutations(scopeID: scope.id)
            }
            if let pushResult = try await drainPushQueue(scopeID: scope.id) {
                return pushResult
            }
            try await synchronizePull(scopeID: scope.id)
            if let retryDate = try await persistence.nextMutationRetryDate(
                scopeID: scope.id
            ) {
                return .retryAt(scopeID: scope.id, date: retryDate)
            }
            return .idle(scopeID: scope.id)
        } catch is CancellationError {
            return .cancelled
        } catch let error as BagLogSyncError {
            return cycleResult(for: error, scopeID: nil)
        } catch {
            return .failed(scopeID: nil, code: "persistence")
        }
    }
}

// MARK: - Profile and scope

extension LoadoutSyncEngine {
    private func prepareScope(
        localProfile: UserProfileSnapshot
    ) async throws -> LoadoutSyncScopeSnapshot {
        let remoteProfile: BagLogRemoteProfile
        do {
            remoteProfile = try await api.ownProfile()
        } catch BagLogSyncError.profileNotFound {
            remoteProfile = try await api.createOwnProfile(
                BagLogProfileWrite(
                    handle: localProfile.handle,
                    displayName: localProfile.displayName,
                    bio: localProfile.bio
                )
            )
        }

        let date = dependencies.now()
        let scope = try await persistence.activateSyncScope(
            remoteProfileID: remoteProfile.id,
            localProfileID: localProfile.id,
            at: date
        )
        try await persistence.bindUnboundPrivateDrafts(
            to: scope.id,
            at: date
        )
        return scope
    }
}

// MARK: - Push

extension LoadoutSyncEngine {
    private func drainPushQueue(
        scopeID: UUID
    ) async throws -> LoadoutSyncCycleResult? {
        while !Task.isCancelled {
            let date = dependencies.now()
            if let attempt = try await persistence.nextMutationAttempt(
                scopeID: scopeID,
                at: date
            ) {
                if let result = try await push(attempt) {
                    return result
                }
                continue
            }
            guard let pendingChange = try await persistence.oldestPendingChange(
                scopeID: scopeID
            ) else {
                return nil
            }
            _ = try await materialize(pendingChange)
        }
        throw CancellationError()
    }

    private func materialize(
        _ pendingChange: PendingLoadoutChangeValue
    ) async throws -> LoadoutMutationAttemptValue {
        let body: Data?
        switch pendingChange.kind {
        case .upsert:
            body = try await api.encodeMutationBody(
                for: LoadoutSyncProjection(snapshot: pendingChange.snapshot)
            )
        case .delete:
            body = nil
        }
        return try await persistence.materializeAttempt(
            MaterializeLoadoutAttemptCommand(
                pendingChangeID: pendingChange.id,
                idempotencyKey: dependencies.makeUUID(),
                encodedBody: body
            )
        )
    }

    private func push(
        _ attempt: LoadoutMutationAttemptValue
    ) async throws -> LoadoutSyncCycleResult? {
        try await persistence.markAttemptStarted(
            idempotencyKey: attempt.idempotencyKey,
            at: dependencies.now()
        )
        do {
            let response = try await api.performMutation(attempt)
            try await persistence.acknowledgeMutation(
                LoadoutMutationAcknowledgement(
                    idempotencyKey: attempt.idempotencyKey,
                    result: response.result,
                    acknowledgedAt: dependencies.now()
                )
            )
            return nil
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as BagLogSyncError {
            return try await handlePushError(error, attempt: attempt)
        }
    }

    private func handlePushError(
        _ error: BagLogSyncError,
        attempt: LoadoutMutationAttemptValue
    ) async throws -> LoadoutSyncCycleResult? {
        switch error {
        case .cancelled:
            throw CancellationError()
        case .revisionMismatch, .loadoutConflict:
            try await preserveConflict(for: attempt)
            return .failed(scopeID: attempt.scopeID, code: error.stableCode)
        case .loadoutNotFound:
            try await preserveTombstoneConflict(for: attempt)
            return .failed(scopeID: attempt.scopeID, code: error.stableCode)
        case let .mutationInProgress(retryAfter):
            return try await scheduleRetry(
                attempt,
                error: error,
                serverDelay: retryAfter
            )
        case .networkUnavailable, .serviceUnavailable, .timedOut, .internalError:
            return try await scheduleRetry(
                attempt,
                error: error,
                serverDelay: nil
            )
        case let .idempotencyConflict(traceID):
            try await persistence.failMutation(
                idempotencyKey: attempt.idempotencyKey,
                failureCode: error.stableCode,
                traceID: traceID
            )
            return .failed(scopeID: attempt.scopeID, code: error.stableCode)
        case .invalidToken:
            return .signedOut
        case .profileRequired:
            return .profileRequired
        default:
            try await persistence.failMutation(
                idempotencyKey: attempt.idempotencyKey,
                failureCode: error.stableCode,
                traceID: nil
            )
            return .failed(scopeID: attempt.scopeID, code: error.stableCode)
        }
    }

    private func preserveConflict(
        for attempt: LoadoutMutationAttemptValue
    ) async throws {
        do {
            let aggregate = try await api.loadout(id: attempt.loadoutID)
            try await persistence.recordMutationConflict(
                idempotencyKey: attempt.idempotencyKey,
                remoteVersion: .aggregate(aggregate),
                detectedAt: dependencies.now()
            )
        } catch BagLogSyncError.loadoutNotFound {
            try await preserveTombstoneConflict(for: attempt)
        }
    }

    private func preserveTombstoneConflict(
        for attempt: LoadoutMutationAttemptValue
    ) async throws {
        let expectedRevision = max(attempt.expectedRevision ?? 0, 0)
        let nextRevision = expectedRevision < Int64.max
            ? max(expectedRevision + 1, 1)
            : Int64.max
        try await persistence.recordMutationConflict(
            idempotencyKey: attempt.idempotencyKey,
            remoteVersion: .tombstone(
                RemoteLoadoutTombstone(
                    id: attempt.loadoutID,
                    revision: nextRevision,
                    deletedAt: dependencies.now()
                )
            ),
            detectedAt: dependencies.now()
        )
    }

    private func scheduleRetry(
        _ attempt: LoadoutMutationAttemptValue,
        error: BagLogSyncError,
        serverDelay: TimeInterval?
    ) async throws -> LoadoutSyncCycleResult {
        let delay = boundedRetryDelay(
            attemptCount: attempt.attemptCount,
            serverDelay: serverDelay
        )
        let retryDate = dependencies.now().addingTimeInterval(delay)
        try await persistence.scheduleMutationRetry(
            idempotencyKey: attempt.idempotencyKey,
            notBefore: retryDate,
            failureCode: error.stableCode
        )
        return .retryAt(scopeID: attempt.scopeID, date: retryDate)
    }

    private func boundedRetryDelay(
        attemptCount: Int,
        serverDelay: TimeInterval?
    ) -> TimeInterval {
        if let serverDelay {
            return min(max(serverDelay, 1), 3_600)
        }
        let exponent = min(max(attemptCount, 0), 6)
        let base = min(5 * pow(2, Double(exponent)), 300)
        let jitterMaximum = min(base * 0.2, 30)
        return base + dependencies.jitter(0...jitterMaximum)
    }
}

// MARK: - Pull

extension LoadoutSyncEngine {
    private func synchronizePull(scopeID: UUID) async throws {
        do {
            try await resumePull(scopeID: scopeID)
        } catch BagLogSyncError.invalidCursor {
            try await restartBootstrap(scopeID: scopeID)
        } catch BagLogSyncError.cursorExpired {
            try await restartBootstrap(scopeID: scopeID)
        }
    }

    private func restartBootstrap(scopeID: UUID) async throws {
        try await persistence.resetPullState(
            scopeID: scopeID,
            at: dependencies.now()
        )
        try await resumePull(scopeID: scopeID)
    }

    private func resumePull(scopeID: UUID) async throws {
        guard var scope = try await persistence.syncScope(id: scopeID) else {
            throw LoadoutSyncPersistenceError.scopeNotFound
        }
        if scope.cursor == nil {
            try await bootstrap(scopeID: scopeID)
            guard let refreshedScope = try await persistence.syncScope(id: scopeID) else {
                throw LoadoutSyncPersistenceError.scopeNotFound
            }
            scope = refreshedScope
        }
        guard let cursor = scope.cursor else {
            throw LoadoutSyncPersistenceError.invalidSyncSnapshot
        }
        try await drainChanges(scopeID: scopeID, initialCursor: cursor)
    }

    private func bootstrap(scopeID: UUID) async throws {
        while !Task.isCancelled {
            guard let scope = try await persistence.syncScope(id: scopeID) else {
                throw LoadoutSyncPersistenceError.scopeNotFound
            }
            let page = try await api.bootstrap(
                cursor: scope.bootstrapCursor,
                after: scope.bootstrapAfter
            )
            try await persistence.applyBootstrapPage(
                scopeID: scopeID,
                loadouts: page.loadouts,
                cursor: page.cursor,
                nextAfter: page.nextAfter,
                hasMore: page.hasMore,
                appliedAt: dependencies.now()
            )
            if !page.hasMore {
                return
            }
        }
        throw CancellationError()
    }

    private func drainChanges(
        scopeID: UUID,
        initialCursor: Int64
    ) async throws {
        var cursor = initialCursor
        while !Task.isCancelled {
            let page = try await api.changes(cursor: cursor)
            try await persistence.applyChangePage(
                scopeID: scopeID,
                changes: page.changes,
                nextCursor: page.nextCursor,
                hasMore: page.hasMore,
                appliedAt: dependencies.now()
            )
            cursor = page.nextCursor
            if !page.hasMore {
                return
            }
        }
        throw CancellationError()
    }
}

// MARK: - Result mapping

extension LoadoutSyncEngine {
    private func cycleResult(
        for error: BagLogSyncError,
        scopeID: UUID?
    ) -> LoadoutSyncCycleResult {
        switch error {
        case .cancelled:
            .cancelled
        case .invalidToken:
            .signedOut
        case .profileNotFound, .profileRequired:
            .profileRequired
        case .profileConflict:
            .profileConflict
        default:
            .failed(scopeID: scopeID, code: error.stableCode)
        }
    }
}
