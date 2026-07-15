//
//  NeutralGradientBackground.swift
//  DesignSystem+BagLog
//
//  Created by Eugene on 15.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

public struct BagLogNeutralGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                .init(0.0, 0.0), .init(0.5, 0.0), .init(1.0, 0.0),
                .init(0.0, 0.5), .init(0.5, 0.5), .init(1.0, 0.5),
                .init(0.0, 1.0), .init(0.5, 1.0), .init(1.0, 1.0)
            ],
            colors: colors,
            background: Color(.systemBackground),
            smoothsColors: true
        )
    }

    private var colors: [Color] {
        switch colorScheme {
        case .dark:
            Self.darkColors
        case .light:
            Self.lightColors
        @unknown default:
            Self.lightColors
        }
    }

    private static let darkColors: [Color] = [
        Color(red: 0.08, green: 0.07, blue: 0.06),
        Color(red: 0.11, green: 0.09, blue: 0.07),
        Color(red: 0.09, green: 0.08, blue: 0.07),
        Color(red: 0.10, green: 0.08, blue: 0.06),
        Color(red: 0.14, green: 0.10, blue: 0.07),
        Color(red: 0.10, green: 0.08, blue: 0.06),
        Color(red: 0.07, green: 0.06, blue: 0.06),
        Color(red: 0.10, green: 0.08, blue: 0.06),
        Color(red: 0.08, green: 0.07, blue: 0.06)
    ]

    private static let lightColors: [Color] = [
        Color(red: 1.00, green: 0.98, blue: 0.95),
        Color(red: 0.99, green: 0.94, blue: 0.84),
        Color(red: 1.00, green: 0.96, blue: 0.89),
        Color(red: 0.99, green: 0.91, blue: 0.80),
        Color(red: 1.00, green: 0.94, blue: 0.86),
        Color(red: 0.99, green: 0.91, blue: 0.80),
        Color(red: 1.00, green: 0.96, blue: 0.90),
        Color(red: 1.00, green: 0.94, blue: 0.84),
        Color(red: 1.00, green: 0.98, blue: 0.95)
    ]
}
