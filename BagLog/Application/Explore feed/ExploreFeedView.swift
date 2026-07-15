//
//  ExploreFeedView.swift
//  BagLog
//
//  Created by Eugene on 13.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct ExploreFeedView: View {

    @Environment(Router.self) private var router

    var body: some View {
        innerContent
    }

    // MARK: - Components
    @ViewBuilder private var innerContent: some View {
        NavigationStack {
            ScrollView {
                rect(height: 128)
                rect(height: 64)
                rect(height: 256)
            }
            .contentMargins(.horizontal, 16)
            .navigationTitle("Explore")
        }
    }

    @ViewBuilder private func rect(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.gray)
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}

#if DEBUG
#Preview {
    ExploreFeedView()
        .environment(Router())
}
#endif
