import Foundation
import Observation
import Services

@MainActor
@Observable
final class AuthenticationStore {
    private(set) var state = AuthenticationState.restoring
    private(set) var message: String?

    private let dependencies: AuthenticationDependencies
    private var retryOperation: AuthenticationRetryOperation?
    private var sessionEventTask: Task<Void, Never>?

    init(dependencies: AuthenticationDependencies) {
        self.dependencies = dependencies
        observeSessionEvents()
    }

    var canRetry: Bool {
        retryOperation != nil
    }

    var sessionController: any BagLogSessionControlling {
        dependencies.sessionController
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
            try await dependencies.sessionController.signIn(
                identityToken: identityToken
            )
            state = .signedIn
        } catch {
            await handleSignInFailure(error)
        }
    }

    func signOut() async {
        guard state == .signedIn else { return }

        state = .signingOut
        clearFailure()

        do {
            try await dependencies.sessionController.signOut()
            dependencies.identityProvider.signOut()
            state = .signedOut
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
        }
    }

    @discardableResult
    func handle(_ url: URL) -> Bool {
        dependencies.identityProvider.handle(url)
    }

    private func restoreSession() async {
        do {
            let isSignedIn = try await dependencies.sessionController.restore()
            state = isSignedIn ? .signedIn : .signedOut
        } catch {
            if await dependencies.sessionController.hasSession() {
                state = .signedIn
                handleFailure(error, retry: .saveSession)
            } else {
                state = .signedOut
                handleFailure(error, retry: .restore)
            }
        }
    }

    private func retrySavingSession() async {
        clearFailure()
        do {
            try await dependencies.sessionController.retryPersistingSession()
            state = .signedIn
        } catch {
            state = .signedIn
            handleFailure(error, retry: .saveSession)
        }
    }

    private func handleSignInFailure(_ error: Error) async {
        if isCancellation(error) {
            state = .signedOut
            clearFailure()
        } else if await dependencies.sessionController.hasSession() {
            state = .signedIn
            handleFailure(error, retry: .saveSession)
        } else {
            state = .signedOut
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

    private func observeSessionEvents() {
        let events = dependencies.sessionController.events
        sessionEventTask = Task { [weak self] in
            for await event in events {
                guard !Task.isCancelled else { return }
                switch event {
                case .invalidated:
                    self?.sessionWasInvalidated()
                }
            }
        }
    }

    private func sessionWasInvalidated() {
        dependencies.identityProvider.signOut()
        state = .signedOut
        clearFailure()
    }
}
