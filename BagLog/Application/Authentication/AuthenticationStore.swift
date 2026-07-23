import Foundation
import Observation
import Services

@MainActor
@Observable
final class AuthenticationStore {
    private(set) var state = AuthenticationState.restoring
    private(set) var message: String?

    private let dependencies: AuthenticationDependencies
    private var session: AuthenticationSession?
    private var retryOperation: AuthenticationRetryOperation?

    init(dependencies: AuthenticationDependencies) {
        self.dependencies = dependencies
    }

    var canRetry: Bool {
        retryOperation != nil
    }

    func restore() async {
        guard state == .restoring else { return }
        await restoreSession()
    }

    func signIn() async {
        guard state == .signedOut else { return }

        state = .signingIn
        clearFailure()

        do {
            let identityToken = try await dependencies.identityProvider.identityToken()
            try Task.checkCancellation()
            let newSession = try await dependencies.api.signIn(identityToken: identityToken)
            session = newSession

            do {
                try await dependencies.sessionStorage.save(newSession)
                state = .signedIn
            } catch {
                state = .signedIn
                showFailure(.secureStorage, retry: .saveSession)
            }
        } catch {
            handleSignInFailure(error)
        }
    }

    func signOut() async {
        guard state == .signedIn, let session else { return }

        state = .signingOut
        clearFailure()

        do {
            let revocableSession = try await sessionForLogout(session)
            try await dependencies.api.logout(accessToken: revocableSession.accessToken)
            await finishLocalSignOut()
        } catch {
            self.state = .signedIn
            handleFailure(error, retry: .signOut)
        }
    }

    func retry() async {
        guard let retryOperation else { return }

        switch retryOperation {
        case .restore:
            state = .restoring
            clearFailure()
            await restoreSession()
        case .signIn:
            clearFailure()
            await signIn()
        case .signOut:
            clearFailure()
            await signOut()
        case .saveSession:
            await retrySavingSession()
        case .finishLocalSignOut:
            state = .signingOut
            clearFailure()
            await finishLocalSignOut()
        }
    }

    @discardableResult
    func handle(_ url: URL) -> Bool {
        dependencies.identityProvider.handle(url)
    }

    private func restoreSession() async {
        do {
            guard let storedSession = try await dependencies.sessionStorage.load() else {
                state = .signedOut
                return
            }
            try Task.checkCancellation()

            let now = dependencies.clock.now
            guard storedSession.refreshExpiresAt > now else {
                try await dependencies.sessionStorage.clear()
                state = .signedOut
                return
            }

            if storedSession.accessExpiresAt > now.addingTimeInterval(30) {
                session = storedSession
                state = .signedIn
                return
            }

            let refreshedSession: AuthenticationSession
            do {
                refreshedSession = try await dependencies.api.refresh(
                    refreshToken: storedSession.refreshToken
                )
            } catch let error as AuthenticationError where
                error == .rejected || error == .invalidRequest {
                try await dependencies.sessionStorage.clear()
                session = nil
                state = .signedOut
                return
            }

            session = refreshedSession
            do {
                try await dependencies.sessionStorage.save(refreshedSession)
                state = .signedIn
            } catch {
                state = .signedIn
                handleFailure(error, retry: .saveSession)
            }
        } catch {
            session = nil
            state = .signedOut
            handleFailure(error, retry: .restore)
        }
    }

    private func finishLocalSignOut() async {
        do {
            try await dependencies.sessionStorage.clear()
            dependencies.identityProvider.signOut()
            session = nil
            state = .signedOut
            clearFailure()
        } catch {
            state = .signedIn
            handleFailure(error, retry: .finishLocalSignOut)
        }
    }

    private func sessionForLogout(
        _ currentSession: AuthenticationSession
    ) async throws -> AuthenticationSession {
        guard currentSession.accessExpiresAt > dependencies.clock.now else {
            let refreshedSession = try await dependencies.api.refresh(
                refreshToken: currentSession.refreshToken
            )
            session = refreshedSession
            try await dependencies.sessionStorage.save(refreshedSession)
            return refreshedSession
        }
        return currentSession
    }

    private func retrySavingSession() async {
        guard let session else {
            state = .signedOut
            clearFailure()
            return
        }

        clearFailure()
        do {
            try await dependencies.sessionStorage.save(session)
            state = .signedIn
        } catch {
            state = .signedIn
            handleFailure(error, retry: .saveSession)
        }
    }

    private func handleSignInFailure(_ error: Error) {
        session = nil
        state = .signedOut

        if isCancellation(error) {
            clearFailure()
        } else {
            handleFailure(error, retry: .signIn)
        }
    }

    private func handleFailure(
        _ error: Error,
        retry: AuthenticationRetryOperation
    ) {
        if isCancellation(error) {
            clearFailure()
            return
        }

        let authenticationError = error as? AuthenticationError ?? .serviceUnavailable
        showFailure(authenticationError, retry: retry)
    }

    private func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? AuthenticationError) == .cancelled
    }

    private func showFailure(
        _ error: AuthenticationError,
        retry: AuthenticationRetryOperation?
    ) {
        message = error.userMessage
        retryOperation = retry
    }

    private func clearFailure() {
        message = nil
        retryOperation = nil
    }
}
