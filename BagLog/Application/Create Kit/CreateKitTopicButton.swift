import Persistence
import SwiftUI

struct CreateKitTopicButton: View {
    @Binding var selection: LoadoutCategory
    let topics: [CreateKitTopic]
    @Bindable var store: CreateKitStore
    let parentFocus: FocusState<CreateKitFocusField?>.Binding

    @State private var destination: CreateKitTopicPickerDestination?

    var body: some View {
        Button(action: presentPicker) {
            HStack(spacing: 8) {
                Image(systemName: selectedTopic.symbol)

                Text(selectedTopic.title)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .accessibilityHidden(true)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(.black.opacity(0.34), in: .capsule)
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.54), lineWidth: 1)
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Topic, \(selectedTopic.title)")
        .accessibilityHint("Opens the topic picker")
        .accessibilityIdentifier("choose-kit-topic")
        .sheet(item: $destination) { _ in
            CreateKitTopicPickerSheet(
                selection: $selection,
                topics: availableTopics,
                store: store
            )
        }
    }

    private var availableTopics: [CreateKitTopic] {
        CreateKitTopic.catalog(topics, including: selection)
    }

    private var selectedTopic: CreateKitTopic {
        if let topic = availableTopics.first(where: { $0.category == selection }) {
            return topic
        }

        return CreateKitTopic(
            id: selection.rawValue,
            title: selection.createKitTitle,
            symbol: selection.createKitSymbol,
            keywords: []
        )
    }

    private func presentPicker() {
        parentFocus.wrappedValue = nil
        destination = CreateKitTopicPickerDestination()
    }
}
