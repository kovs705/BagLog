//
//  ProfileAuthenticationView.swift
//  BagLog
//
//  Create by Eugene Kovs on 23.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct ProfileAuthenticationView: View {
    
    @Environment(AuthenticationStore.self) private var authenticationStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading) {
            switch authenticationStore.state {
            case .restoring:
                ProgressView("Restoring your BagLog session…")
                    .accessibilityIdentifier("authentication-progress")
            case .signedOut, .signingIn:
                ProfileSignedOutAuthenticationView(
                    isSigningIn: authenticationStore.state == .signingIn,
                    colorScheme: colorScheme,
                    signIn: signIn
                )
            case .signedIn, .signingOut:
                ProfileSignedInAuthenticationView(
                    isSigningOut: authenticationStore.state == .signingOut,
                    signOut: signOut
                )
            }

            if let message = authenticationStore.message, !message.isEmpty {
                Label(message, systemImage: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("authentication-error")

                if authenticationStore.canRetry {
                    Button("Try Again", action: retry)
                        .accessibilityIdentifier("authentication-retry-button")
                }
            }
        }
    }

    private func signIn() {
        Task {
            await authenticationStore.signIn()
        }
    }

    private func signOut() {
        Task {
            await authenticationStore.signOut()
        }
    }

    private func retry() {
        Task {
            await authenticationStore.retry()
        }
    }
}
