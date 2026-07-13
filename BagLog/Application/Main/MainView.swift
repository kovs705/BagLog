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
                Tab("Expore", systemImage: "mail.stack", value: .explore) {
                    exploreFeed
                }
                
                Tab("My Kits", systemImage: "duffle.bag.fill", value: .myKits) {
                    myKits
                }
                
                Tab("My Profile", systemImage: "person", value: .profile, role: .search) {
                    profile
                }
            }
        )
        .sheet(isPresented: $router.createKitIsPresented) {
            CreateKitView()
        }
        .tabViewBottomAccessory {
            Button("Create kit") {
                router.createKitIsPresented.toggle()
            }
            .buttonStyle(.plain)
            .contentShape(.rect)
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
    
    @ViewBuilder private var createKit: some View {
        CreateKitView()
    }
}

#if DEBUG
#Preview {
    MainView()
}
#endif
