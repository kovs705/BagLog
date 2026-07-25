//
//  CKTopicSearchField.swift
//  BagLog
//
//  Created by Eugene Kovs on 24.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct CreateKitTopicSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Search topics", text: $text)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .accessibilityIdentifier("topic-search")

            if !text.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill", action: clear)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(.regularMaterial, in: .capsule)
        .overlay {
            Capsule()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
    }

    private func clear() {
        text = ""
    }
}
