import SwiftUI

struct CreateKitLinkEditor: View {
    @Binding var link: CreateKitLinkDraft
    let itemID: UUID
    @Bindable var store: CreateKitStore
    let focus: FocusState<CreateKitFocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: CreateKitDesign.cardSpacing) {
            HStack {
                TextField("Label (optional)", text: $link.label)
                    .submitLabel(.next)
                    .focused(focus, equals: .linkLabel(itemID: itemID, linkID: link.id))
                    .onSubmit(focusURL)
                    .onChange(of: link.label, store.markTextChanged)

                Button("Remove link", systemImage: "minus.circle", role: .destructive, action: remove)
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
            }

            TextField("https://example.com", text: $link.urlString)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused(focus, equals: .linkURL(itemID: itemID, linkID: link.id))
                .onSubmit(focusComposer)
                .onChange(of: link.urlString, store.markTextChanged)

            if !link.urlString.isEmpty && !link.isValid {
                Label("Use a complete HTTPS address", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.thinMaterial, in: .rect(cornerRadius: CreateKitDesign.compactCornerRadius))
    }

    private func focusURL() {
        focus.wrappedValue = .linkURL(itemID: itemID, linkID: link.id)
    }

    private func focusComposer() {
        focus.wrappedValue = .composer
    }

    private func remove() {
        store.removeLink(id: link.id, from: itemID)
    }
}
