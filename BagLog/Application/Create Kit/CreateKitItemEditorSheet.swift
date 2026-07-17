import SwiftUI

struct CreateKitItemEditorSheet: View {
    @Binding var item: CreateKitItemDraft
    @Bindable var store: CreateKitStore

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: CreateKitFocusField?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CreateKitDesign.sectionSpacing) {
                    Label("Pack the details", systemImage: "shippingbox.fill")
                        .font(.title2)
                        .bold()

                    Text("Add the details you’ll want when packing this kit.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    CreateKitItemDetailsView(
                        item: $item,
                        store: store,
                        focus: $focusedField
                    )
                    .padding(CreateKitDesign.sectionSpacing)
                    .background(
                        .regularMaterial,
                        in: .rect(cornerRadius: CreateKitDesign.cardCornerRadius)
                    )
                }
                .padding(CreateKitDesign.horizontalPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Item details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", action: finishEditing)
                        .buttonStyle(.glassProminent)
                        .tint(.orange)
                        .accessibilityIdentifier("finish-item-editor")
                }

                CreateKitItemKeyboardToolbar(
                    item: item,
                    focus: $focusedField
                )
            }
            .supportNeutralGradientBackground()
            .accessibilityIdentifier("item-editor-sheet")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .presentationCornerRadius(32)
    }

    private func finishEditing() {
        focusedField = nil
        dismiss()
    }
}
