import SwiftUI

struct CreateKitTagEditor: View {
    let tags: [String]
    @Bindable var store: CreateKitStore

    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: CreateKitDesign.cardSpacing) {
            Label("Tags", systemImage: "tag")
                .font(.headline)

            if !tags.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(tags, id: \.self) { tag in
                            Button {
                                store.removeTag(tag)
                            } label: {
                                Label(tag, systemImage: "xmark")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityHint("Removes this tag")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            TextField("Add a tag", text: $newTag)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit(addTag)
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: CreateKitDesign.cardCornerRadius))
    }

    private func addTag() {
        store.addTag(newTag)
        newTag = ""
    }
}
