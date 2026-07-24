//
//  ProfileSignedInAuthenticationView.swift
//  BagLog
//
//  Create by Eugene Kovs on 23.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct ProfileSignedInAuthenticationView: View {
    
    let isSigningOut: Bool
    let signOut: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Label("Signed in with Google", systemImage: "checkmark.circle.fill")
                .accessibilityIdentifier("authentication-signed-in")

            Text("Your local profile and kits remain separate from this account.")
                .foregroundStyle(.secondary)

            Button(
                "Sign Out",
                systemImage: "rectangle.portrait.and.arrow.right",
                role: .destructive,
                action: signOut
            )
            .disabled(isSigningOut)
            .accessibilityIdentifier("google-sign-out-button")

            if isSigningOut {
                ProgressView("Signing out…")
                    .accessibilityIdentifier("authentication-progress")
            }
        }
    }
}
