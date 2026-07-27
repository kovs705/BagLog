import Foundation
import SwiftData

@Model
public final class LoadoutSyncScope {
    #Unique<LoadoutSyncScope>([\.remoteProfileID])
    #Index<LoadoutSyncScope>([\.localProfileID], [\.updatedAt])

    public var id: UUID
    public var remoteProfileID: UUID
    public var localProfileID: UUID
    public var cursor: Int64?
    public var bootstrapCursor: Int64?
    public var bootstrapAfter: UUID?
    public var bootstrapStateRaw: String
    public var lastCompletedAt: Date?
    public var lastFailureCode: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        remoteProfileID: UUID,
        localProfileID: UUID,
        createdAt: Date
    ) {
        self.id = id
        self.remoteProfileID = remoteProfileID
        self.localProfileID = localProfileID
        bootstrapStateRaw = LoadoutBootstrapState.notStarted.rawValue
        self.createdAt = createdAt
        updatedAt = createdAt
    }

    public var bootstrapState: LoadoutBootstrapState {
        get {
            LoadoutBootstrapState(rawValue: bootstrapStateRaw) ?? .notStarted
        }
        set {
            bootstrapStateRaw = newValue.rawValue
        }
    }
}
