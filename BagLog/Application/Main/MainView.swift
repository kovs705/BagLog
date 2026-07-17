//
//  MainView.swift
//  BagLog
//
//  Created by Eugene on 13.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct MainView: View {

    @Environment(Router.self) private var router

    var body: some View {
        innerContent
    }

    // MARK: - Components
    @ViewBuilder private var innerContent: some View {
        @Bindable var router = router

        TabView(
            selection: $router.selection,
            content: {
                Tab("Explore", systemImage: "mail.stack", value: .explore) {
                    exploreFeed
                }

                Tab("My Kits", systemImage: "duffle.bag.fill", value: .myKits) {
                    myKits
                }

                Tab("My Profile", systemImage: "person", value: .profile) {
                    profile
                }
            }
        )
        .fullScreenCover(item: $router.createKitPresentation, onDismiss: router.editorDidDismiss) { presentation in
            CreateKitView(presentation: presentation)
        }
        .tabViewBottomAccessory {
            Button("Create kit", systemImage: "plus", action: router.presentNewKit)
                .buttonStyle(.plain)
                .contentShape(.rect)
                .accessibilityIdentifier("create-kit-button")
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    @ViewBuilder private var exploreFeed: some View {
        ExploreFeedView()
    }

    @ViewBuilder private var profile: some View {
        ProfileView()
    }

    @ViewBuilder private var myKits: some View {
        MyKitsView()
    }

}

#if DEBUG
#Preview {
    MainView()
}
#endif
