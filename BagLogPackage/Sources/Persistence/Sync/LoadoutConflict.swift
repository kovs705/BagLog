import Foundation
import SwiftData

@Model
public final class LoadoutConflict {
    #Unique<LoadoutConflict>([\.loadoutID])
    #Index<LoadoutConflict>([\.scopeID], [\.detectedAt])

    public var id: UUID
    public var scopeID: UUID
    public var loadoutID: UUID
    public var baseRevision: Int64?
    public var localSnapshotData: Data
    public var remoteSnapshotData: Data?
    public var remoteRevision: Int64
    public var remoteCreatedAt: Date?
    public var remoteChangedAt: Date
    public var isRemoteTombstone: Bool
    public var detectedAt: Date

    public init(
        id: UUID = UUID(),
        scopeID: UUID,
        loadoutID: UUID,
        baseRevision: Int64?,
        localSnapshotData: Data,
        remoteSnapshotData: Data?,
        remoteRevision: Int64,
        remoteCreatedAt: Date?,
        remoteChangedAt: Date,
        isRemoteTombstone: Bool,
        detectedAt: Date
    ) {
        self.id = id
        self.scopeID = scopeID
        self.loadoutID = loadoutID
        self.baseRevision = baseRevision
        self.localSnapshotData = localSnapshotData
        self.remoteSnapshotData = remoteSnapshotData
        self.remoteRevision = remoteRevision
        self.remoteCreatedAt = remoteCreatedAt
        self.remoteChangedAt = remoteChangedAt
        self.isRemoteTombstone = isRemoteTombstone
        self.detectedAt = detectedAt
    }
}
