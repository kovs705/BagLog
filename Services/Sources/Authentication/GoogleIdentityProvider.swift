import Foundation
import GoogleSignIn
import UIKit

@MainActor
public final class GoogleIdentityProvider: GoogleIdentityProviding {
    private let bundle: Bundle

    public init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    public func identityToken() async throws -> String {
        let configuration = try googleConfiguration()
        guard let presentingViewController = presentingViewController() else {
            throw AuthenticationError.providerUnavailable
        }

        GIDSignIn.sharedInstance.configuration = configuration

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingViewController
            )
            guard let identityToken = result.user.idToken?.tokenString,
                  !identityToken.isEmpty else {
                throw AuthenticationError.missingIdentityToken
            }
            return identityToken
        } catch let error as AuthenticationError {
            throw error
        } catch let error as NSError where
            error.domain == kGIDSignInErrorDomain &&
            error.code == GIDSignInError.Code.canceled.rawValue {
            throw AuthenticationError.cancelled
        } catch is CancellationError {
            throw AuthenticationError.cancelled
        } catch {
            throw AuthenticationError.providerUnavailable
        }
    }

    public func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    public func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    private func googleConfiguration() throws -> GIDConfiguration {
        guard let clientID = configuredValue(for: "GIDClientID"),
              let serverClientID = configuredValue(for: "GIDServerClientID") else {
            throw AuthenticationError.configuration
        }
        return GIDConfiguration(
            clientID: clientID,
            serverClientID: serverClientID
        )
    }

    private func configuredValue(for key: String) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.contains("NOT_CONFIGURED") else { return nil }
        return value
    }

    private func presentingViewController() -> UIViewController? {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let rootViewController = windowScene?.windows
            .first(where: \.isKeyWindow)?
            .rootViewController
        return rootViewController?.frontmostViewController
    }
}

private extension UIViewController {
    var frontmostViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.frontmostViewController
        }
        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.frontmostViewController
        }
        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.frontmostViewController
        }
        return self
    }
}
