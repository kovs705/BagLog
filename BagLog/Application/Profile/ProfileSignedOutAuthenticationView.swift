import GoogleSignInSwift
import SwiftUI

struct ProfileSignedOutAuthenticationView: View {
    let isSigningIn: Bool
    let colorScheme: ColorScheme
    let signIn: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Text("Sign in to create or open a BagLog account. Your local content stays on this device and is not synchronized by this feature.")
                .foregroundStyle(.secondary)

            GoogleSignInButton(
                scheme: colorScheme == .dark ? .dark : .light,
                style: .wide,
                state: isSigningIn ? .disabled : .normal,
                action: signIn
            )
            .disabled(isSigningIn)
            .accessibilityLabel("Sign in with Google")
            .accessibilityIdentifier("google-sign-in-button")

            if isSigningIn {
                ProgressView("Signing in…")
                    .accessibilityIdentifier("authentication-progress")
            }
        }
    }
}
