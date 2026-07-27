import Foundation
import SwiftData

@Model
public final class PendingLoadoutChange {
    #Unique<PendingLoadoutChange>([\.id])
    #Index<PendingLoadoutChange>(
        [\.scopeID],
        [\.loadoutID],
        [\.createdAt]
    )

    public var id: UUID
    public var scopeID: UUID
    public var loadoutID: UUID
    public var kindRaw: String
    public var deleteReasonRaw: String?
    public var localGeneration: Int64
    public var snapshotData: Data
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        scopeID: UUID,
        loadoutID: UUID,
        kind: PendingLoadoutChangeKind,
        deleteReason: LoadoutDeleteReason?,
        localGeneration: Int64,
        snapshotData: Data,
        createdAt: Date
    ) {
        self.id = id
        self.scopeID = scopeID
        self.loadoutID = loadoutID
        kindRaw = kind.rawValue
        deleteReasonRaw = deleteReason?.rawValue
        self.localGeneration = localGeneration
        self.snapshotData = snapshotData
        self.createdAt = createdAt
    }

    public var kind: PendingLoadoutChangeKind {
        get {
            PendingLoadoutChangeKind(rawValue: kindRaw) ?? .upsert
        }
        set {
            kindRaw = newValue.rawValue
        }
    }

    public var deleteReason: LoadoutDeleteReason? {
        get {
            deleteReasonRaw.flatMap(LoadoutDeleteReason.init(rawValue:))
        }
        set {
            deleteReasonRaw = newValue?.rawValue
        }
    }
}
