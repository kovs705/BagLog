import Foundation

public enum BagLogSessionEvent: Sendable {
    case invalidated
}

public protocol BagLogSessionControlling: BagLogAccessTokenProviding {
    var events: AsyncStream<BagLogSessionEvent> { get }

    func restore() async throws -> Bool
    func signIn(identityToken: String) async throws
    func signOut() async throws
    func retryPersistingSession() async throws
    func hasSession() async -> Bool
}

public actor BagLogSessionController: BagLogSessionControlling {
    public nonisolated let events: AsyncStream<BagLogSessionEvent>

    private static let refreshLeeway: TimeInterval = 30

    private let api: any AuthenticationAPIProviding
    private let storage: any AuthenticationSessionStoring
    private let clock: any AuthenticationClock
    private let eventContinuation: AsyncStream<BagLogSessionEvent>.Continuation

    private var session: AuthenticationSession?
    private var refreshTask: Task<AuthenticationSession, Error>?
    private var needsLocalClear = false

    public init(
        api: any AuthenticationAPIProviding,
        storage: any AuthenticationSessionStoring,
        clock: any AuthenticationClock
    ) {
        self.api = api
        self.storage = storage
        self.clock = clock
        let stream = AsyncStream<BagLogSessionEvent>.makeStream()
        events = stream.stream
        eventContinuation = stream.continuation
    }

    public func restore() async throws -> Bool {
        guard let storedSession = try await loadStoredSession() else {
            session = nil
            return false
        }
        guard storedSession.refreshExpiresAt > clock.now else {
            try await clearSession(notify: false)
            return false
        }
        session = storedSession
        guard shouldRefresh(storedSession) else {
            return true
        }

        do {
            _ = try await rotatedSession()
            return true
        } catch let error as AuthenticationError
            where error == .rejected || error == .invalidRequest {
            return false
        }
    }

    public func signIn(identityToken: String) async throws {
        let authenticatedSession = try await api.signIn(identityToken: identityToken)
        session = authenticatedSession
        do {
            try await storage.save(authenticatedSession)
        } catch {
            throw AuthenticationError.secureStorage
        }
    }

    public func signOut() async throws {
        if needsLocalClear {
            try await clearAfterRevocation()
            return
        }
        let accessToken = try await validAccessToken()
        try await api.logout(accessToken: accessToken)
        needsLocalClear = true
        try await clearAfterRevocation()
    }

    public func retryPersistingSession() async throws {
        guard let session else {
            throw AuthenticationError.rejected
        }
        do {
            try await storage.save(session)
        } catch {
            throw AuthenticationError.secureStorage
        }
    }

    public func hasSession() -> Bool {
        session != nil
    }

    public func validAccessToken() async throws -> String {
        guard let session else {
            throw AuthenticationError.rejected
        }
        if shouldRefresh(session) {
            return try await rotatedSession().accessToken
        }
        return session.accessToken
    }

    public func refreshAccessToken() async throws -> String {
        try await rotatedSession().accessToken
    }

    private func rotatedSession() async throws -> AuthenticationSession {
        if let refreshTask {
            return try await refreshTask.value
        }
        guard let session,
              session.refreshExpiresAt > clock.now else {
            try await clearSession(notify: true)
            throw AuthenticationError.rejected
        }

        let task = makeRefreshTask(refreshToken: session.refreshToken)
        refreshTask = task
        do {
            let rotatedSession = try await task.value
            self.session = rotatedSession
            refreshTask = nil
            return rotatedSession
        } catch {
            refreshTask = nil
            try await handleRefreshFailure(error)
        }
    }

    private func makeRefreshTask(
        refreshToken: String
    ) -> Task<AuthenticationSession, Error> {
        let api = api
        let storage = storage
        return Task {
            let rotatedSession = try await api.refresh(refreshToken: refreshToken)
            do {
                try await storage.save(rotatedSession)
            } catch {
                throw SessionControllerError.persistence(rotatedSession)
            }
            return rotatedSession
        }
    }

    private func handleRefreshFailure(
        _ error: Error
    ) async throws -> Never {
        if case let SessionControllerError.persistence(rotatedSession) = error {
            session = rotatedSession
            throw AuthenticationError.secureStorage
        }
        if let authenticationError = error as? AuthenticationError,
           authenticationError == .rejected || authenticationError == .invalidRequest {
            try await clearSession(notify: true)
        }
        throw error
    }

    private func loadStoredSession() async throws -> AuthenticationSession? {
        do {
            return try await storage.load()
        } catch {
            throw AuthenticationError.secureStorage
        }
    }

    private func clearAfterRevocation() async throws {
        do {
            try await storage.clear()
        } catch {
            throw AuthenticationError.secureStorage
        }
        needsLocalClear = false
        session = nil
    }

    private func clearSession(notify: Bool) async throws {
        session = nil
        refreshTask?.cancel()
        refreshTask = nil
        if notify {
            eventContinuation.yield(.invalidated)
        }
        do {
            try await storage.clear()
        } catch {
            throw AuthenticationError.secureStorage
        }
    }

    private func shouldRefresh(_ session: AuthenticationSession) -> Bool {
        session.accessExpiresAt <= clock.now.addingTimeInterval(Self.refreshLeeway)
    }
}

private enum SessionControllerError: Error {
    case persistence(AuthenticationSession)
}
