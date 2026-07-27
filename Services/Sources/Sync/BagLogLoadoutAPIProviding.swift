import Foundation
import Persistence

public struct BagLogProfileWrite: Sendable, Equatable {
    public let handle: String
    public let displayName: String
    public let bio: String?

    public init(handle: String, displayName: String, bio: String?) {
        self.handle = handle
        self.displayName = displayName
        self.bio = bio
    }
}

public struct BagLogRemoteProfile: Sendable, Equatable {
    public let id: UUID
    public let revision: Int64

    public init(id: UUID, revision: Int64) {
        self.id = id
        self.revision = revision
    }
}

public struct BagLogMutationResponse: Sendable, Equatable {
    public let result: LoadoutMutationResult
    public let wasReplayed: Bool

    public init(result: LoadoutMutationResult, wasReplayed: Bool) {
        self.result = result
        self.wasReplayed = wasReplayed
    }
}

public struct BagLogBootstrapPage: Sendable, Equatable {
    public let loadouts: [RemoteLoadoutAggregate]
    public let cursor: Int64
    public let nextAfter: UUID?
    public let hasMore: Bool

    public init(
        loadouts: [RemoteLoadoutAggregate],
        cursor: Int64,
        nextAfter: UUID?,
        hasMore: Bool
    ) {
        self.loadouts = loadouts
        self.cursor = cursor
        self.nextAfter = nextAfter
        self.hasMore = hasMore
    }
}

public struct BagLogChangePage: Sendable, Equatable {
    public let changes: [RemoteLoadoutChange]
    public let nextCursor: Int64
    public let hasMore: Bool

    public init(
        changes: [RemoteLoadoutChange],
        nextCursor: Int64,
        hasMore: Bool
    ) {
        self.changes = changes
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

public protocol BagLogLoadoutAPIProviding: Sendable {
    func ownProfile() async throws -> BagLogRemoteProfile
    func createOwnProfile(_ write: BagLogProfileWrite) async throws -> BagLogRemoteProfile
    func encodeMutationBody(for projection: LoadoutSyncProjection) async throws -> Data
    func performMutation(
        _ attempt: LoadoutMutationAttemptValue
    ) async throws -> BagLogMutationResponse
    func loadout(id: UUID) async throws -> RemoteLoadoutAggregate
    func bootstrap(cursor: Int64?, after: UUID?) async throws -> BagLogBootstrapPage
    func changes(cursor: Int64) async throws -> BagLogChangePage
}
