import Foundation
import SwiftData

@Model
public final class LoadoutMutationAttempt {
    #Unique<LoadoutMutationAttempt>(
        [\.idempotencyKey],
        [\.pendingChangeID]
    )
    #Index<LoadoutMutationAttempt>(
        [\.pendingChangeID],
        [\.scopeID],
        [\.loadoutID],
        [\.retryNotBefore]
    )

    public var idempotencyKey: UUID
    public var pendingChangeID: UUID
    public var scopeID: UUID
    public var loadoutID: UUID
    public var operationRaw: String
    public var expectedRevision: Int64?
    public var encodedBody: Data?
    public var snapshotData: Data
    public var localGeneration: Int64
    public var stateRaw: String
    public var firstAttemptedAt: Date?
    public var retryNotBefore: Date?
    public var attemptCount: Int
    public var failureCode: String?
    public var traceID: String?

    public init(
        idempotencyKey: UUID,
        pendingChangeID: UUID,
        scopeID: UUID,
        loadoutID: UUID,
        operation: LoadoutMutationOperation,
        expectedRevision: Int64?,
        encodedBody: Data?,
        snapshotData: Data,
        localGeneration: Int64
    ) {
        self.idempotencyKey = idempotencyKey
        self.pendingChangeID = pendingChangeID
        self.scopeID = scopeID
        self.loadoutID = loadoutID
        operationRaw = operation.rawValue
        self.expectedRevision = expectedRevision
        self.encodedBody = encodedBody
        self.snapshotData = snapshotData
        self.localGeneration = localGeneration
        stateRaw = LoadoutMutationAttemptState.ready.rawValue
        attemptCount = 0
    }

    public var operation: LoadoutMutationOperation {
        LoadoutMutationOperation(rawValue: operationRaw) ?? .create
    }

    public var state: LoadoutMutationAttemptState {
        get {
            LoadoutMutationAttemptState(rawValue: stateRaw) ?? .failed
        }
        set {
            stateRaw = newValue.rawValue
        }
    }
}
