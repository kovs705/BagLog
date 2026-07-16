import SwiftUI

struct CreateKitComposerBar: View {
    @Bindable var store: CreateKitStore
    let focus: FocusState<CreateKitFocusField?>.Binding
    let reduceMotion: Bool

    var body: some View {
        GlassEffectContainer(spacing: CreateKitDesign.cardSpacing) {
            HStack(alignment: .bottom, spacing: CreateKitDesign.cardSpacing) {
                TextField("Add an item", text: $store.composerText, axis: .vertical)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .focused(focus, equals: .composer)
                    .onSubmit(addItem)
                    .onChange(of: store.composerText, submitCompletedLines)
                    .padding(.horizontal)
                    .frame(minHeight: 48)
                    .glassEffect(
                        .regular.interactive(),
                        in: .rect(cornerRadius: CreateKitDesign.cardCornerRadius)
                    )
                    .accessibilityIdentifier("item-composer")

                Button("Add item", systemImage: "arrow.up", action: addItem)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(store.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityInputLabels(["Add item", "Send"])
            }
        }
        .padding(.horizontal, CreateKitDesign.horizontalPadding)
        .padding(.vertical, 8)
    }

    private func addItem() {
        let itemName = store.composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !itemName.isEmpty else { return }

        addItem(named: itemName)
    }

    private func submitCompletedLines(
        _ oldValue: String,
        _ newValue: String
    ) {
        let lines = newValue.components(separatedBy: .newlines)
        guard lines.count > 1 else { return }

        for completedLine in lines.dropLast() {
            let itemName = completedLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !itemName.isEmpty else { continue }
            store.composerText = itemName
            addItem(named: itemName)
        }

        store.composerText = lines.last ?? ""
        focus.wrappedValue = .composer
    }

    private func addItem(named itemName: String) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .bouncy) {
            store.composerText = itemName
            store.addComposedItem()
        }
        AccessibilityNotification.Announcement("\(itemName) added").post()
        focus.wrappedValue = .composer
    }
}
