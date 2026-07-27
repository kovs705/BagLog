import Foundation
import Persistence
import Services
import Testing

@Suite("Private loadout sync engine", .serialized)
struct LoadoutSyncEngineTests {
    private let now = Date(timeIntervalSince1970: 2_100_000_000)

    @Test("Offline mutation retries the exact durable attempt after relaunch")
    func offlineRetryAndRelaunch() async throws {
        let setup = try await makeSetup()
        await setup.api.setMutationOutcomes([.failure(.networkUnavailable), .success])
        let firstEngine = makeEngine(setup: setup)

        let firstResult = await firstEngine.runCycle(context: setup.context)
        guard case let .retryAt(scopeID, retryDate) = firstResult else {
            Issue.record("Expected a persisted retry")
            return
        }
        let firstAttempt = try #require(
            await setup.persistence.nextMutationAttempt(
                scopeID: scopeID,
                at: retryDate
            )
        )
        setup.clock.advance(to: retryDate.addingTimeInterval(1))

        let relaunchedEngine = makeEngine(setup: setup)
        let secondResult = await relaunchedEngine.runCycle(context: setup.context)
        guard case .idle = secondResult else {
            Issue.record("Expected the relaunched engine to converge")
            return
        }
        let received = await setup.api.receivedAttempts

        #expect(received.count == 2)
        #expect(received[0].idempotencyKey == received[1].idempotencyKey)
        #expect(received[0].encodedBody == received[1].encodedBody)
        #expect(received[0].idempotencyKey == firstAttempt.idempotencyKey)
        #expect(
            try await setup.persistence.oldestPendingChange(scopeID: scopeID) == nil
        )
    }

    @Test("A stale replace preserves both versions as a conflict")
    func staleReplaceCreatesConflict() async throws {
        let setup = try await makeSetup()
        let engine = makeEngine(setup: setup)
        guard case let .idle(scopeID) = await engine.runCycle(context: setup.context) else {
            Issue.record("Expected initial synchronization")
            return
        }
        let synchronized = try #require(
            await setup.persistence.loadouts().first
        )
        _ = try await setup.persistence.saveLoadout(
            SaveLoadoutCommand(
                id: synchronized.id,
                ownerID: setup.profile.id,
                title: "This device"
            )
        )
        await setup.api.setRemoteAggregate(
            RemoteLoadoutAggregate(
                projection: LoadoutSyncProjection(
                    id: synchronized.id,
                    title: "Server version",
                    summary: "",
                    category: "other",
                    items: [],
                    tags: []
                ),
                revision: 2,
                createdAt: now,
                updatedAt: now.addingTimeInterval(1)
            )
        )
        await setup.api.setMutationOutcomes([.failure(.revisionMismatch)])

        let result = await engine.runCycle(context: setup.context)
        guard case .failed = result else {
            Issue.record("Expected a conflict failure")
            return
        }
        let conflict = try #require(
            await setup.persistence.conflict(loadoutID: synchronized.id)
        )

        #expect(conflict.scopeID == scopeID)
        #expect(conflict.localSnapshot.title == "This device")
        guard case let .aggregate(remote) = conflict.remoteVersion else {
            Issue.record("Expected server version")
            return
        }
        #expect(remote.projection.title == "Server version")
    }

    @Test("Cursor expiry restarts bootstrap without dropping local work")
    func cursorExpiryRestartsBootstrap() async throws {
        let setup = try await makeSetup()
        await setup.api.setChangeOutcomes([.failure(.cursorExpired), .success])
        let engine = makeEngine(setup: setup)

        let result = await engine.runCycle(context: setup.context)

        guard case .idle = result else {
            Issue.record("Expected bootstrap recovery")
            return
        }
        #expect(await setup.api.bootstrapCallCount == 2)
        #expect(await setup.api.changeCallCount == 2)
        #expect((try await setup.persistence.loadouts()).count == 1)
    }

    @Test("A different account scope never claims the first scope's queue")
    func accountSwitchIsolation() async throws {
        let setup = try await makeSetup()
        await setup.api.setMutationOutcomes([.failure(.networkUnavailable)])
        let engine = makeEngine(setup: setup)
        guard case let .retryAt(firstScopeID, _) = await engine.runCycle(
            context: setup.context
        ) else {
            Issue.record("Expected first account retry")
            return
        }
        let firstAttempts = await setup.api.receivedAttempts
        await setup.api.setProfileID(UUID())
        await setup.api.setMutationOutcomes([.success])

        let result = await engine.runCycle(context: setup.context)
        guard case let .idle(secondScopeID) = result else {
            Issue.record("Expected second account to remain idle")
            return
        }

        #expect(secondScopeID != firstScopeID)
        #expect(await setup.api.receivedAttempts == firstAttempts)
        #expect(
            try await setup.persistence.nextMutationRetryDate(scopeID: firstScopeID)
                != nil
        )
    }

    @Test("A disabled cycle makes no profile or loadout requests")
    func disabledFeatureMakesNoRequests() async throws {
        let setup = try await makeSetup()
        let engine = makeEngine(setup: setup)
        let context = LoadoutSyncRunContext(
            isFeatureEnabled: false,
            isForeground: true,
            isAuthenticated: true,
            localProfile: setup.profile
        )

        let result = await engine.runCycle(context: context)

        #expect(result == .disabled)
        #expect(await setup.api.profileCallCount == 0)
        #expect(await setup.api.bootstrapCallCount == 0)
        #expect(await setup.api.changeCallCount == 0)
        #expect(await setup.api.receivedAttempts.isEmpty)
    }

    @Test("Mutation-in-progress persists the server retry deadline")
    func mutationInProgressPersistsRetryAfter() async throws {
        let setup = try await makeSetup()
        await setup.api.setMutationOutcomes([
            .failure(.mutationInProgress(retryAfter: 42))
        ])
        let engine = makeEngine(setup: setup)

        let result = await engine.runCycle(context: setup.context)
        guard case let .retryAt(scopeID, retryDate) = result else {
            Issue.record("Expected a persisted retry deadline")
            return
        }

        #expect(retryDate == now.addingTimeInterval(42))
        #expect(
            try await setup.persistence.nextMutationAttempt(
                scopeID: scopeID,
                at: now
            ) == nil
        )
        #expect(
            try await setup.persistence.nextMutationRetryDate(scopeID: scopeID)
                == retryDate
        )
    }

    private func makeSetup() async throws -> Setup {
        let persistence = SwiftDataPersistence(
            modelContainer: try BagLogModelContainer.make(isStoredInMemoryOnly: true)
        )
        let profile = try await persistence.saveProfile(
            SaveUserProfileCommand(handle: "owner", displayName: "Owner")
        )
        _ = try await persistence.saveLoadout(
            SaveLoadoutCommand(ownerID: profile.id, title: "Offline draft")
        )
        let api = TestLoadoutSyncAPI(now: now)
        let clock = TestAuthenticationClock(now: now)
        return Setup(
            persistence: persistence,
            profile: profile,
            api: api,
            clock: clock
        )
    }

    private func makeEngine(setup: Setup) -> LoadoutSyncEngine {
        LoadoutSyncEngine(
            api: setup.api,
            persistence: setup.persistence,
            dependencies: LoadoutSyncEngineDependencies(
                now: { setup.clock.now },
                makeUUID: { UUID() },
                jitter: { _ in 0 }
            )
        )
    }

    private struct Setup {
        let persistence: SwiftDataPersistence
        let profile: UserProfileSnapshot
        let api: TestLoadoutSyncAPI
        let clock: TestAuthenticationClock

        var context: LoadoutSyncRunContext {
            LoadoutSyncRunContext(
                isFeatureEnabled: true,
                isForeground: true,
                isAuthenticated: true,
                localProfile: profile
            )
        }
    }
}

private enum TestMutationOutcome: Sendable {
    case success
    case failure(BagLogSyncError)
}

private enum TestChangeOutcome: Sendable {
    case success
    case failure(BagLogSyncError)
}

private actor TestLoadoutSyncAPI: BagLogLoadoutAPIProviding {
    private var profileID = UUID()
    private var mutationOutcomes: [TestMutationOutcome] = [.success]
    private var changeOutcomes: [TestChangeOutcome] = [.success]
    private var remoteAggregate: RemoteLoadoutAggregate?
    private let now: Date

    private(set) var receivedAttempts: [LoadoutMutationAttemptValue] = []
    private(set) var profileCallCount = 0
    private(set) var bootstrapCallCount = 0
    private(set) var changeCallCount = 0

    init(now: Date) {
        self.now = now
    }

    func setProfileID(_ profileID: UUID) {
        self.profileID = profileID
    }

    func setMutationOutcomes(_ outcomes: [TestMutationOutcome]) {
        mutationOutcomes = outcomes
    }

    func setChangeOutcomes(_ outcomes: [TestChangeOutcome]) {
        changeOutcomes = outcomes
    }

    func setRemoteAggregate(_ aggregate: RemoteLoadoutAggregate) {
        remoteAggregate = aggregate
    }

    func ownProfile() -> BagLogRemoteProfile {
        profileCallCount += 1
        return BagLogRemoteProfile(id: profileID, revision: 1)
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
        receivedAttempts.append(attempt)
        let outcome = mutationOutcomes.isEmpty
            ? TestMutationOutcome.success
            : mutationOutcomes.removeFirst()
        if case let .failure(error) = outcome {
            throw error
        }
        let expectedRevision = max(attempt.expectedRevision ?? 0, 0)
        let revision = expectedRevision < Int64.max
            ? max(expectedRevision + 1, 1)
            : Int64.max
        if attempt.operation == .delete {
            return BagLogMutationResponse(
                result: .tombstone(
                    RemoteLoadoutTombstone(
                        id: attempt.loadoutID,
                        revision: revision,
                        deletedAt: now
                    )
                ),
                wasReplayed: receivedAttempts.count > 1
            )
        }
        let projection = try decodedProjection(attempt)
        return BagLogMutationResponse(
            result: .aggregate(
                RemoteLoadoutAggregate(
                    projection: projection,
                    revision: revision,
                    createdAt: now,
                    updatedAt: now
                )
            ),
            wasReplayed: receivedAttempts.count > 1
        )
    }

    func loadout(id: UUID) throws -> RemoteLoadoutAggregate {
        guard let remoteAggregate, remoteAggregate.projection.id == id else {
            throw BagLogSyncError.loadoutNotFound
        }
        return remoteAggregate
    }

    func bootstrap(
        cursor: Int64?,
        after: UUID?
    ) -> BagLogBootstrapPage {
        bootstrapCallCount += 1
        return BagLogBootstrapPage(
            loadouts: [],
            cursor: cursor ?? 0,
            nextAfter: nil,
            hasMore: false
        )
    }

    func changes(cursor: Int64) throws -> BagLogChangePage {
        changeCallCount += 1
        let outcome = changeOutcomes.isEmpty
            ? TestChangeOutcome.success
            : changeOutcomes.removeFirst()
        if case let .failure(error) = outcome {
            throw error
        }
        return BagLogChangePage(
            changes: [],
            nextCursor: cursor,
            hasMore: false
        )
    }

    private func decodedProjection(
        _ attempt: LoadoutMutationAttemptValue
    ) throws -> LoadoutSyncProjection {
        guard let body = attempt.encodedBody else {
            throw BagLogSyncError.invalidRequest
        }
        return try JSONDecoder().decode(LoadoutSyncProjection.self, from: body)
    }
}
