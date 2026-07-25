//
//  CreateKitTopicPickerSheet.swift
//  BagLog
//
//  Created by Eugene Kovs on 24.07.2026.
//  https://github.com/kovs705
//

import Persistence
import SwiftUI

struct CreateKitTopicPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selection: LoadoutCategory
    let topics: [CreateKitTopic]
    @Bindable var store: CreateKitStore

    @State private var searchText = ""
    @State private var selectedDetent = PresentationDetent.large

    var body: some View {
        NavigationStack {
            Group {
                if displayedTopics.isEmpty {
                    ContentUnavailableView.search
                } else {
                    List(displayedTopics) { topic in
                        CreateKitTopicRow(
                            topic: topic,
                            isSelected: topic.category == selection,
                            select: { select(topic) }
                        )
                        .listRowInsets(
                            EdgeInsets(
                                top: 5,
                                leading: CreateKitDesign.horizontalPadding,
                                bottom: 5,
                                trailing: CreateKitDesign.horizontalPadding
                            )
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Choose a topic")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search topics")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark", action: dismiss.callAsFunction)
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("close-topic-picker")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Text("^[\(filteredTopics.count) topic](inflect: true)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .supportNeutralGradientBackground()
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .presentationCornerRadius(32)
    }

    private var filteredTopics: [CreateKitTopic] {
        topics.filter { $0.matches(searchText) }
    }

    private var displayedTopics: [CreateKitTopic] {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let selectionIndex = filteredTopics.firstIndex(where: {
                  $0.category == selection
              }),
              selectionIndex != filteredTopics.startIndex else {
            return filteredTopics
        }

        var orderedTopics = filteredTopics
        let selectedTopic = orderedTopics.remove(at: selectionIndex)
        orderedTopics.insert(selectedTopic, at: orderedTopics.startIndex)
        return orderedTopics
    }

    private func select(_ topic: CreateKitTopic) {
        guard topic.category != selection else {
            dismiss()
            return
        }

        selection = topic.category
        store.markStructureChanged()
        dismiss()
    }
}
