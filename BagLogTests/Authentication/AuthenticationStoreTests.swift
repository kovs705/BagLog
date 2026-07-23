import Foundation
import Services
import Testing
@testable import BagLog

@Suite("Authentication store")
@MainActor
struct AuthenticationStoreTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("A Google credential is exchanged, saved, and presented as signed in")
    func successfulSignIn() async throws {
        let provider = TestGoogleIdentityProvider(token: "google-token")
        let api = TestAuthenticationAPI(signInSession: session())
        let storage = TestAuthenticationSessionStorage()
        let store = makeStore(provider: provider, api: api, storage: storage)
        await store.restore()

        await store.signIn()

        #expect(store.state == .signedIn)
        #expect(await api.identityTokens() == ["google-token"])
        #expect(await storage.currentSession() == session())
        #expect(store.message == nil)
    }

    @Test("A Keychain save failure keeps the live session and can be retried")
    func sessionSaveRetry() async {
        let provider = TestGoogleIdentityProvider(token: "google-token")
        let api = TestAuthenticationAPI(signInSession: session())
        let storage = TestAuthenticationSessionStorage(saveFailuresRemaining: 1)
        let store = makeStore(provider: provider, api: api, storage: storage)
        await store.restore()

        await store.signIn()

        #expect(store.state == .signedIn)
        #expect(store.message == AuthenticationError.secureStorage.userMessage)
        #expect(store.canRetry)
        #expect(await storage.currentSession() == nil)

        await store.retry()

        #expect(store.state == .signedIn)
        #expect(store.message == nil)
        #expect(await storage.currentSession() == session())
    }

    @Test("Provider cancellation is a silent return to signed out")
    func providerCancellation() async {
        let provider = TestGoogleIdentityProvider(error: AuthenticationError.cancelled)
        let api = TestAuthenticationAPI(signInSession: session())
        let storage = TestAuthenticationSessionStorage()
        let store = makeStore(provider: provider, api: api, storage: storage)
        await store.restore()

        await store.signIn()

        #expect(store.state == .signedOut)
        #expect(store.message == nil)
        #expect(await api.identityTokens().isEmpty)
    }

    @Test("A missing Google ID token does not call the backend")
    func missingIdentityToken() async {
        let provider = TestGoogleIdentityProvider(token: nil)
        let api = TestAuthenticationAPI(signInSession: session())
        let storage = TestAuthenticationSessionStorage()
        let store = makeStore(provider: provider, api: api, storage: storage)
        await store.restore()

        await store.signIn()

        #expect(store.state == .signedOut)
        #expect(store.message == AuthenticationError.missingIdentityToken.userMessage)
        #expect(await api.identityTokens().isEmpty)
    }

    @Test("Repeated activation starts only one provider flow")
    func duplicateTapSuppression() async {
        let provider = TestGoogleIdentityProvider(delay: .milliseconds(100))
        let api = TestAuthenticationAPI(signInSession: session())
        let storage = TestAuthenticationSessionStorage()
        let store = makeStore(provider: provider, api: api, storage: storage)
        await store.restore()

        let firstAttempt = Task { await store.signIn() }
        await Task.yield()
        let secondAttempt = Task { await store.signIn() }
        await firstAttempt.value
        await secondAttempt.value

        #expect(provider.identityTokenCallCount == 1)
        #expect(await api.identityTokens().count == 1)
        #expect(store.state == .signedIn)
    }

    @Test("A usable access token restores without a network request")
    func validSessionRestore() async {
        let validSession = session(accessExpiresAt: now.addingTimeInterval(600))
        let provider = TestGoogleIdentityProvider()
        let api = TestAuthenticationAPI(signInSession: session())
        let storage = TestAuthenticationSessionStorage(session: validSession)
        let store = makeStore(provider: provider, api: api, storage: storage)

        await store.restore()

        #expect(store.state == .signedIn)
        #expect(await api.refreshTokens().isEmpty)
    }

    @Test("An expired access token refreshes and atomically replaces the pair")
    func refreshRotation() async {
        let expiredSession = session(
            accessToken: "old-access",
            accessExpiresAt: now.addingTimeInterval(-1),
            refreshToken: "old-refresh"
        )
        let rotatedSession = session(
            accessToken: "new-access",
            accessExpiresAt: now.addingTimeInterval(600),
            refreshToken: "new-refresh"
        )
        let provider = TestGoogleIdentityProvider()
        let api = TestAuthenticationAPI(
            signInSession: session(),
            refreshSession: rotatedSession
        )
        let storage = TestAuthenticationSessionStorage(session: expiredSession)
        let store = makeStore(provider: provider, api: api, storage: storage)

        await store.restore()

        #expect(store.state == .signedIn)
        #expect(await api.refreshTokens() == ["old-refresh"])
        #expect(await storage.currentSession() == rotatedSession)
        #expect(await storage.savedSessions() == [rotatedSession])
    }

    @Test("A rejected refresh clears the stored BagLog session")
    func rejectedRefresh() async {
        let expiredSession = session(accessExpiresAt: now.addingTimeInterval(-1))
        let provider = TestGoogleIdentityProvider()
        let api = TestAuthenticationAPI(
            signInSession: session(),
            refreshError: AuthenticationError.rejected
        )
        let storage = TestAuthenticationSessionStorage(session: expiredSession)
        let store = makeStore(provider: provider, api: api, storage: storage)

        await store.restore()

        #expect(store.state == .signedOut)
        #expect(await storage.currentSession() == nil)
        #expect(await storage.clearCount() == 1)
    }

    @Test("Logout revokes the backend before clearing local provider state")
    func logoutSuccess() async {
        let validSession = session(accessExpiresAt: now.addingTimeInterval(600))
        let provider = TestGoogleIdentityProvider()
        let api = TestAuthenticationAPI(signInSession: validSession)
        let storage = TestAuthenticationSessionStorage(session: validSession)
        let store = makeStore(provider: provider, api: api, storage: storage)
        await store.restore()

        await store.signOut()

        #expect(await api.logoutTokens() == [validSession.accessToken])
        #expect(await storage.currentSession() == nil)
        #expect(provider.signOutCallCount == 1)
        #expect(store.state == .signedOut)
    }

    @Test("Logout refreshes an expired access token before backend revocation")
    func logoutRefreshesExpiredAccess() async {
        let initialSession = session(
            accessToken: "initial-access",
            accessExpiresAt: now.addingTimeInterval(600),
            refreshToken: "current-refresh"
        )
        let refreshedSession = session(
            accessToken: "fresh-access",
            accessExpiresAt: now.addingTimeInterval(600),
            refreshToken: "rotated-refresh"
        )
        let provider = TestGoogleIdentityProvider()
        let api = TestAuthenticationAPI(
            signInSession: refreshedSession,
            refreshSession: refreshedSession
        )
        let storage = TestAuthenticationSessionStorage(session: initialSession)
        let clock = TestAuthenticationClock(now: now)
        let store = AuthenticationStore(
            dependencies: AuthenticationDependencies(
                identityProvider: provider,
                api: api,
                sessionStorage: storage,
                clock: clock
            )
        )
        await store.restore()
        clock.advance(to: now.addingTimeInterval(1_000))

        await store.signOut()

        #expect(await api.logoutTokens().last == "fresh-access")
        #expect(await storage.currentSession() == nil)
        #expect(store.state == .signedOut)
    }

    @Test("Logout failure retains both BagLog and Google sessions")
    func logoutFailure() async {
        let validSession = session(accessExpiresAt: now.addingTimeInterval(600))
        let provider = TestGoogleIdentityProvider()
        let api = TestAuthenticationAPI(
            signInSession: validSession,
            logoutError: AuthenticationError.serviceUnavailable
        )
        let storage = TestAuthenticationSessionStorage(session: validSession)
        let store = makeStore(provider: provider, api: api, storage: storage)
        await store.restore()

        await store.signOut()

        #expect(store.state == .signedIn)
        #expect(await storage.currentSession() == validSession)
        #expect(provider.signOutCallCount == 0)
        #expect(store.message == AuthenticationError.serviceUnavailable.userMessage)
        #expect(store.canRetry)
    }

    @Test("Cancellation during Google authentication returns silently")
    func providerTaskCancellation() async {
        let provider = TestGoogleIdentityProvider(delay: .seconds(10))
        let api = TestAuthenticationAPI(signInSession: session())
        let storage = TestAuthenticationSessionStorage()
        let store = makeStore(provider: provider, api: api, storage: storage)
        await store.restore()

        let task = Task { await store.signIn() }
        await Task.yield()
        task.cancel()
        await task.value

        #expect(store.state == .signedOut)
        #expect(store.message == nil)
        #expect(await api.identityTokens().isEmpty)
    }

    @Test("Cancellation during the backend exchange does not save a session")
    func backendTaskCancellation() async {
        let provider = TestGoogleIdentityProvider()
        let api = TestAuthenticationAPI(
            signInSession: session(),
            signInDelay: .seconds(10)
        )
        let storage = TestAuthenticationSessionStorage()
        let store = makeStore(provider: provider, api: api, storage: storage)
        await store.restore()

        let task = Task { await store.signIn() }
        for _ in 0..<100 {
            if !(await api.identityTokens()).isEmpty {
                break
            }
            await Task.yield()
        }
        task.cancel()
        await task.value

        #expect(store.state == .signedOut)
        #expect(store.message == nil)
        #expect(await storage.currentSession() == nil)
    }

    private func makeStore(
        provider: TestGoogleIdentityProvider,
        api: TestAuthenticationAPI,
        storage: TestAuthenticationSessionStorage
    ) -> AuthenticationStore {
        AuthenticationStore(
            dependencies: AuthenticationDependencies(
                identityProvider: provider,
                api: api,
                sessionStorage: storage,
                clock: TestAuthenticationClock(now: now)
            )
        )
    }

    private func session(
        accessToken: String = "access-token",
        accessExpiresAt: Date? = nil,
        refreshToken: String = "refresh-token"
    ) -> AuthenticationSession {
        AuthenticationSession(
            accessToken: accessToken,
            accessExpiresAt: accessExpiresAt ?? now.addingTimeInterval(600),
            refreshToken: refreshToken,
            refreshExpiresAt: now.addingTimeInterval(86_400),
            tokenType: "Bearer"
        )
    }
}
