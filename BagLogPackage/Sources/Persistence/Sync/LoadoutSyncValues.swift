import Foundation

public enum LoadoutBootstrapState: String, Codable, Sendable {
    case notStarted
    case inProgress
    case complete
}

public enum PendingLoadoutChangeKind: String, Codable, Sendable {
    case upsert
    case delete
}

public enum LoadoutDeleteReason: String, Codable, Sendable {
    case userDeleted
    case eligibilityDetach
}

public enum LoadoutMutationOperation: String, Codable, Sendable {
    case create
    case replace
    case delete
}

public enum LoadoutMutationAttemptState: String, Codable, Sendable {
    case ready
    case inFlight
    case retryScheduled
    case failed
    case conflicted
}

public struct LoadoutSyncScopeSnapshot: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let remoteProfileID: UUID
    public let localProfileID: UUID
    public let cursor: Int64?
    public let bootstrapCursor: Int64?
    public let bootstrapAfter: UUID?
    public let bootstrapState: LoadoutBootstrapState
    public let lastCompletedAt: Date?
    public let lastFailureCode: String?

    public init(
        id: UUID,
        remoteProfileID: UUID,
        localProfileID: UUID,
        cursor: Int64?,
        bootstrapCursor: Int64?,
        bootstrapAfter: UUID?,
        bootstrapState: LoadoutBootstrapState,
        lastCompletedAt: Date?,
        lastFailureCode: String?
    ) {
        self.id = id
        self.remoteProfileID = remoteProfileID
        self.localProfileID = localProfileID
        self.cursor = cursor
        self.bootstrapCursor = bootstrapCursor
        self.bootstrapAfter = bootstrapAfter
        self.bootstrapState = bootstrapState
        self.lastCompletedAt = lastCompletedAt
        self.lastFailureCode = lastFailureCode
    }
}

public struct LoadoutSyncLink: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let urlString: String
    public let label: String?

    public init(id: UUID, urlString: String, label: String?) {
        self.id = id
        self.urlString = urlString
        self.label = label
    }
}

public struct LoadoutSyncItem: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let category: String?
    public let brand: String?
    public let model: String?
    public let notes: String?
    public let quantity: Int
    public let isEssential: Bool
    public let links: [LoadoutSyncLink]

    public init(
        id: UUID,
        title: String,
        category: String?,
        brand: String?,
        model: String?,
        notes: String?,
        quantity: Int,
        isEssential: Bool,
        links: [LoadoutSyncLink]
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.brand = brand
        self.model = model
        self.notes = notes
        self.quantity = quantity
        self.isEssential = isEssential
        self.links = links
    }
}

public struct LoadoutSyncProjection: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let summary: String
    public let category: String
    public let items: [LoadoutSyncItem]
    public let tags: [String]

    public init(
        id: UUID,
        title: String,
        summary: String,
        category: String,
        items: [LoadoutSyncItem],
        tags: [String]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.category = category
        self.items = items
        self.tags = tags
    }

    public init(snapshot: LoadoutSnapshot) {
        id = snapshot.id
        title = snapshot.title
        summary = snapshot.summary
        category = snapshot.category.rawValue
        items = snapshot.items.map { item in
            LoadoutSyncItem(
                id: item.id,
                title: item.title,
                category: item.category,
                brand: item.brand,
                model: item.model,
                notes: item.notes,
                quantity: item.quantity,
                isEssential: item.isEssential,
                links: item.links.map {
                    LoadoutSyncLink(
                        id: $0.id,
                        urlString: $0.urlString,
                        label: $0.label
                    )
                }
            )
        }
        tags = snapshot.tagNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .uniqued()
            .sorted()
    }
}

public struct RemoteLoadoutAggregate: Sendable, Equatable {
    public let projection: LoadoutSyncProjection
    public let revision: Int64
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        projection: LoadoutSyncProjection,
        revision: Int64,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.projection = projection
        self.revision = revision
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct RemoteLoadoutTombstone: Sendable, Equatable {
    public let id: UUID
    public let revision: Int64
    public let deletedAt: Date

    public init(id: UUID, revision: Int64, deletedAt: Date) {
        self.id = id
        self.revision = revision
        self.deletedAt = deletedAt
    }
}

public enum RemoteLoadoutChangePayload: Sendable, Equatable {
    case upsert(RemoteLoadoutAggregate)
    case delete(RemoteLoadoutTombstone)
}

public struct RemoteLoadoutChange: Sendable, Equatable {
    public let cursor: Int64
    public let resourceID: UUID
    public let revision: Int64
    public let changedAt: Date
    public let payload: RemoteLoadoutChangePayload

    public init(
        cursor: Int64,
        resourceID: UUID,
        revision: Int64,
        changedAt: Date,
        payload: RemoteLoadoutChangePayload
    ) {
        self.cursor = cursor
        self.resourceID = resourceID
        self.revision = revision
        self.changedAt = changedAt
        self.payload = payload
    }
}

public struct PendingLoadoutChangeValue: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let scopeID: UUID
    public let loadoutID: UUID
    public let kind: PendingLoadoutChangeKind
    public let deleteReason: LoadoutDeleteReason?
    public let localGeneration: Int64
    public let snapshot: LoadoutSnapshot
    public let expectedRevision: Int64?
    public let createdAt: Date

    public init(
        id: UUID,
        scopeID: UUID,
        loadoutID: UUID,
        kind: PendingLoadoutChangeKind,
        deleteReason: LoadoutDeleteReason?,
        localGeneration: Int64,
        snapshot: LoadoutSnapshot,
        expectedRevision: Int64?,
        createdAt: Date
    ) {
        self.id = id
        self.scopeID = scopeID
        self.loadoutID = loadoutID
        self.kind = kind
        self.deleteReason = deleteReason
        self.localGeneration = localGeneration
        self.snapshot = snapshot
        self.expectedRevision = expectedRevision
        self.createdAt = createdAt
    }
}

public struct LoadoutMutationAttemptValue: Sendable, Equatable, Identifiable {
    public var id: UUID {
        idempotencyKey
    }

    public let idempotencyKey: UUID
    public let pendingChangeID: UUID
    public let scopeID: UUID
    public let loadoutID: UUID
    public let operation: LoadoutMutationOperation
    public let expectedRevision: Int64?
    public let encodedBody: Data?
    public let localGeneration: Int64
    public let state: LoadoutMutationAttemptState
    public let firstAttemptedAt: Date?
    public let retryNotBefore: Date?
    public let attemptCount: Int

    public init(
        idempotencyKey: UUID,
        pendingChangeID: UUID,
        scopeID: UUID,
        loadoutID: UUID,
        operation: LoadoutMutationOperation,
        expectedRevision: Int64?,
        encodedBody: Data?,
        localGeneration: Int64,
        state: LoadoutMutationAttemptState,
        firstAttemptedAt: Date?,
        retryNotBefore: Date?,
        attemptCount: Int
    ) {
        self.idempotencyKey = idempotencyKey
        self.pendingChangeID = pendingChangeID
        self.scopeID = scopeID
        self.loadoutID = loadoutID
        self.operation = operation
        self.expectedRevision = expectedRevision
        self.encodedBody = encodedBody
        self.localGeneration = localGeneration
        self.state = state
        self.firstAttemptedAt = firstAttemptedAt
        self.retryNotBefore = retryNotBefore
        self.attemptCount = attemptCount
    }
}

public struct MaterializeLoadoutAttemptCommand: Sendable {
    public let pendingChangeID: UUID
    public let idempotencyKey: UUID
    public let encodedBody: Data?

    public init(
        pendingChangeID: UUID,
        idempotencyKey: UUID,
        encodedBody: Data?
    ) {
        self.pendingChangeID = pendingChangeID
        self.idempotencyKey = idempotencyKey
        self.encodedBody = encodedBody
    }
}

public enum LoadoutMutationResult: Sendable, Equatable {
    case aggregate(RemoteLoadoutAggregate)
    case tombstone(RemoteLoadoutTombstone)
}

public struct LoadoutMutationAcknowledgement: Sendable {
    public let idempotencyKey: UUID
    public let result: LoadoutMutationResult
    public let acknowledgedAt: Date

    public init(
        idempotencyKey: UUID,
        result: LoadoutMutationResult,
        acknowledgedAt: Date
    ) {
        self.idempotencyKey = idempotencyKey
        self.result = result
        self.acknowledgedAt = acknowledgedAt
    }
}

public enum LoadoutConflictRemoteVersion: Sendable, Equatable {
    case aggregate(RemoteLoadoutAggregate)
    case tombstone(RemoteLoadoutTombstone)
}

public struct LoadoutConflictSnapshot: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let scopeID: UUID
    public let loadoutID: UUID
    public let baseRevision: Int64?
    public let localOperation: LoadoutMutationOperation
    public let localDeleteReason: LoadoutDeleteReason?
    public let localSnapshot: LoadoutSnapshot
    public let remoteVersion: LoadoutConflictRemoteVersion
    public let detectedAt: Date
}

public enum LoadoutConflictResolution: Sendable {
    case useThisDevice
    case useServerVersion
    case saveAsNewDraft
    case acceptDeletion
}

public enum LoadoutSyncPersistenceError: Error, Equatable, Sendable {
    case accountScopeMismatch
    case attemptInvariantViolation
    case conflictNotFound
    case detachedLoadoutCannotResynchronize
    case invalidRemoteRevision
    case invalidSyncSnapshot
    case scopeNotFound
}

public protocol BagLogSyncPersisting: BagLogPersisting {
    func activateSyncScope(
        remoteProfileID: UUID,
        localProfileID: UUID,
        at date: Date
    ) async throws -> LoadoutSyncScopeSnapshot
    func deactivateSyncScope() async
    func bindUnboundPrivateDrafts(to scopeID: UUID, at date: Date) async throws
    func syncScope(id: UUID) async throws -> LoadoutSyncScopeSnapshot?
    func oldestPendingChange(scopeID: UUID) async throws -> PendingLoadoutChangeValue?
    func nextMutationAttempt(
        scopeID: UUID,
        at date: Date
    ) async throws -> LoadoutMutationAttemptValue?
    func nextMutationRetryDate(scopeID: UUID) async throws -> Date?
    func retryFailedMutations(scopeID: UUID) async throws
    func materializeAttempt(
        _ command: MaterializeLoadoutAttemptCommand
    ) async throws -> LoadoutMutationAttemptValue
    func markAttemptStarted(idempotencyKey: UUID, at date: Date) async throws
    func acknowledgeMutation(_ acknowledgement: LoadoutMutationAcknowledgement) async throws
    func scheduleMutationRetry(
        idempotencyKey: UUID,
        notBefore: Date,
        failureCode: String?
    ) async throws
    func failMutation(
        idempotencyKey: UUID,
        failureCode: String,
        traceID: String?
    ) async throws
    func recordMutationConflict(
        idempotencyKey: UUID,
        remoteVersion: LoadoutConflictRemoteVersion,
        detectedAt: Date
    ) async throws
    func applyBootstrapPage(
        scopeID: UUID,
        loadouts: [RemoteLoadoutAggregate],
        cursor: Int64,
        nextAfter: UUID?,
        hasMore: Bool,
        appliedAt: Date
    ) async throws
    func applyChangePage(
        scopeID: UUID,
        changes: [RemoteLoadoutChange],
        nextCursor: Int64,
        hasMore: Bool,
        appliedAt: Date
    ) async throws
    func resetPullState(scopeID: UUID, at date: Date) async throws
    func conflict(loadoutID: UUID) async throws -> LoadoutConflictSnapshot?
    func resolveConflict(
        loadoutID: UUID,
        resolution: LoadoutConflictResolution,
        at date: Date
    ) async throws -> LoadoutSnapshot?
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
