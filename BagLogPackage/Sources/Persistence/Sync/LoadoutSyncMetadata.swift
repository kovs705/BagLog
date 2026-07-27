import Foundation
import SwiftData

@Model
public final class LoadoutSyncMetadata {
    #Unique<LoadoutSyncMetadata>([\.loadoutID])
    #Index<LoadoutSyncMetadata>([\.scopeID], [\.updatedAt])

    public var id: UUID
    public var loadoutID: UUID
    public var scopeID: UUID?
    public var acknowledgedRevision: Int64?
    public var localGeneration: Int64
    public var remoteCreatedAt: Date?
    public var remoteUpdatedAt: Date?
    public var lastSyncedAt: Date?
    public var isDetached: Bool
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        loadoutID: UUID,
        scopeID: UUID?,
        acknowledgedRevision: Int64? = nil,
        localGeneration: Int64 = 0,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.loadoutID = loadoutID
        self.scopeID = scopeID
        self.acknowledgedRevision = acknowledgedRevision
        self.localGeneration = localGeneration
        isDetached = false
        self.updatedAt = updatedAt
    }
}
