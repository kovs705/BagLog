//
//  MyKitsView.swift
//  BagLog
//
//  Created by Eugene on 13.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct MyKitsView: View {
    
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
                description: Text("Your kits will be here")
            )
        }
        .navigationTitle("My Kits")
    }
}

#if DEBUG
#Preview {
    MyKitsView()
        .environment(Router())
}
#endif
