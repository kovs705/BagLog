//
//  ProfileView.swift
//  BagLog
//
//  Created by Eugene on 13.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct ProfileView: View {
    
    @Environment(Router.self) private var router
    
    var body: some View {
        innerContent
    }
    
    // MARK: - Components
    @ViewBuilder private var innerContent: some View {
        NavigationStack {
            ContentUnavailableView(
                "BagLog",
                systemImage: "backpack",
                description: Text("Here is your profile page")
            )
        }
        .navigationTitle("Hello, Eugene")
    }
}

#if DEBUG
#Preview {
    ProfileView()
        .environment(Router())
}
#endif
