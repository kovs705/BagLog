//
//  Backgrounds.swift
//  DesignSystem+BagLog
//
//  Created by Eugene on 14.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

public extension View {

    func supportNeutralGradientBackground() -> some View {
        self
            .background {
                BagLogNeutralGradientBackground()
                    .ignoresSafeArea()
            }
    }
}

#Preview("Neutral gradient · Light") {
    previewContent
        .supportNeutralGradientBackground()
        .preferredColorScheme(.light)
}

#Preview("Neutral gradient · Dark") {
    previewContent
        .supportNeutralGradientBackground()
        .preferredColorScheme(.dark)
}

private var previewContent: some View {
    ContentUnavailableView(
        "Your next kit",
        systemImage: "duffle.bag.fill",
        description: Text("A native neutral gradient supports every appearance.")
    )
    .foregroundStyle(.primary)
}
