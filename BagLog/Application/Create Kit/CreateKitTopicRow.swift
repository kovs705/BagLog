import SwiftUI

struct CreateKitTopicRow: View {
    let topic: CreateKitTopic
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: CreateKitDesign.cardSpacing) {
                Image(systemName: topic.symbol)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .orange)
                    .frame(width: 46, height: 46)
                    .background(
                        isSelected ? Color.orange : Color.orange.opacity(0.12),
                        in: .rect(cornerRadius: 14)
                    )

                Text(topic.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.orange : Color.secondary.opacity(0.45))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: .rect(cornerRadius: CreateKitDesign.itemCornerRadius))
            .contentShape(.rect(cornerRadius: CreateKitDesign.itemCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityHint("Selects this topic and closes the sheet")
        .accessibilityIdentifier("topic-option-\(topic.id)")
    }
}
