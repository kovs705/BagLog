//
//  ProfileView.swift
//  BagLog
//
//  Created by Eugene on 13.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Local profile") {
                    Label(
                        "Your local kits and profile remain available without an account.",
                        systemImage: "iphone"
                    )
                }

                Section("BagLog account") {
                    ProfileAuthenticationView()
                }
            }
            .navigationTitle("My Profile")
        }
    }
}
