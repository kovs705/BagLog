#if DEBUG
import Foundation
import Persistence
import Services

actor LoadoutSyncUITestAPI: BagLogLoadoutAPIProviding {
    private let profileID = UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1)
    )

    func ownProfile() -> BagLogRemoteProfile {
        BagLogRemoteProfile(id: profileID, revision: 1)
    }

    func createOwnProfile(
        _ write: BagLogProfileWrite
    ) -> BagLogRemoteProfile {
        BagLogRemoteProfile(id: profileID, revision: 1)
    }

    func encodeMutationBody(
        for projection: LoadoutSyncProjection
    ) throws -> Data {
        try JSONEncoder().encode(projection)
    }

    func performMutation(
        _ attempt: LoadoutMutationAttemptValue
    ) throws -> BagLogMutationResponse {
        let expectedRevision = max(attempt.expectedRevision ?? 0, 0)
        let revision = expectedRevision < Int64.max
            ? max(expectedRevision + 1, 1)
            : Int64.max
        let result: LoadoutMutationResult
        if attempt.operation == .delete {
            result = .tombstone(
                RemoteLoadoutTombstone(
                    id: attempt.loadoutID,
                    revision: revision,
                    deletedAt: .now
                )
            )
        } else {
            let projection = try decodedProjection(from: attempt)
            result = .aggregate(
                RemoteLoadoutAggregate(
                    projection: projection,
                    revision: revision,
                    createdAt: .now,
                    updatedAt: .now
                )
            )
        }
        return BagLogMutationResponse(result: result, wasReplayed: false)
    }

    func loadout(id: UUID) throws -> RemoteLoadoutAggregate {
        throw BagLogSyncError.loadoutNotFound
    }

    func bootstrap(
        cursor: Int64?,
        after: UUID?
    ) -> BagLogBootstrapPage {
        BagLogBootstrapPage(
            loadouts: [],
            cursor: cursor ?? 0,
            nextAfter: nil,
            hasMore: false
        )
    }

    func changes(cursor: Int64) -> BagLogChangePage {
        BagLogChangePage(changes: [], nextCursor: cursor, hasMore: false)
    }

    private func decodedProjection(
        from attempt: LoadoutMutationAttemptValue
    ) throws -> LoadoutSyncProjection {
        guard let data = attempt.encodedBody,
              let projection = try? JSONDecoder().decode(
                  LoadoutSyncProjection.self,
                  from: data
              ) else {
            return LoadoutSyncProjection(
                id: attempt.loadoutID,
                title: "UI Test Draft",
                summary: "",
                category: "other",
                items: [],
                tags: []
            )
        }
        return projection
    }
}
#endif
