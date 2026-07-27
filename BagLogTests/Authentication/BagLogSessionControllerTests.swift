import Foundation
import Services
import Testing

@Suite("BagLog session controller")
struct BagLogSessionControllerTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("Concurrent token requests share one rotating refresh")
    func deduplicatesRefresh() async throws {
        let initial = session(
            accessToken: "old-access",
            accessExpiresAt: now.addingTimeInterval(600),
            refreshToken: "old-refresh"
        )
        let rotated = session(
            accessToken: "new-access",
            accessExpiresAt: now.addingTimeInterval(1_200),
            refreshToken: "new-refresh"
        )
        let api = TestAuthenticationAPI(
            signInSession: rotated,
            refreshSession: rotated,
            refreshDelay: .milliseconds(100)
        )
        let storage = TestAuthenticationSessionStorage(session: initial)
        let clock = TestAuthenticationClock(now: now)
        let controller = BagLogSessionController(
            api: api,
            storage: storage,
            clock: clock
        )
        #expect(try await controller.restore())
        clock.advance(to: now.addingTimeInterval(700))

        async let first = controller.validAccessToken()
        async let second = controller.validAccessToken()
        let tokens = try await [first, second]

        #expect(tokens == ["new-access", "new-access"])
        #expect(await api.refreshTokens() == ["old-refresh"])
        #expect(await storage.currentSession() == rotated)
    }

    @Test("A rejected refresh invalidates UI state even when local clearing fails")
    func rejectedRefreshAlwaysNotifies() async throws {
        let initial = session(
            accessToken: "expired-access",
            accessExpiresAt: now,
            refreshToken: "rejected-refresh"
        )
        let api = TestAuthenticationAPI(
            signInSession: initial,
            refreshError: AuthenticationError.rejected
        )
        let storage = TestAuthenticationSessionStorage(
            session: initial,
            clearError: AuthenticationError.secureStorage
        )
        let controller = BagLogSessionController(
            api: api,
            storage: storage,
            clock: TestAuthenticationClock(now: now)
        )
        var events = controller.events.makeAsyncIterator()

        await #expect(throws: AuthenticationError.secureStorage) {
            _ = try await controller.restore()
        }
        let event = await events.next()

        guard let event else {
            Issue.record("Expected session invalidation")
            return
        }
        switch event {
        case .invalidated:
            break
        }
        #expect(await controller.hasSession() == false)
    }

    private func session(
        accessToken: String,
        accessExpiresAt: Date,
        refreshToken: String
    ) -> AuthenticationSession {
        AuthenticationSession(
            accessToken: accessToken,
            accessExpiresAt: accessExpiresAt,
            refreshToken: refreshToken,
            refreshExpiresAt: now.addingTimeInterval(86_400),
            tokenType: "Bearer"
        )
    }
}
