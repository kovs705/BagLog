import SwiftUI

struct CreateKitLinksEditor: View {
    @Binding var item: CreateKitItemDraft
    @Bindable var store: CreateKitStore
    let focus: FocusState<CreateKitFocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: CreateKitDesign.cardSpacing) {
            HStack {
                Label("Links", systemImage: "link")
                    .font(.headline)

                Spacer()

                Button("Add link", systemImage: "plus", action: addLink)
                    .buttonStyle(.bordered)
            }

            ForEach($item.links) { $link in
                CreateKitLinkEditor(
                    link: $link,
                    itemID: item.id,
                    store: store,
                    focus: focus
                )
            }
        }
    }

    private func addLink() {
        store.addLink(to: item.id)
        guard let linkID = item.links.last?.id else { return }
        focus.wrappedValue = .linkURL(itemID: item.id, linkID: linkID)
    }
}
