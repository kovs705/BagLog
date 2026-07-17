import SwiftUI

struct CreateKitTagEditor: View {
    let tags: [String]
    @Bindable var store: CreateKitStore

    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: CreateKitDesign.cardSpacing) {
            Label("Tags", systemImage: "tag")
                .font(.headline)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            store.removeTag(tag)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "tag")
                                Text(tag)
                                Image(systemName: "xmark")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(.orange.tertiary, in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Removes this tag")
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .foregroundStyle(.secondary)

                        TextField("Add tag", text: $newTag)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit(addTag)
                    }
                    .padding(.horizontal, 14)
                    .frame(minWidth: 124, minHeight: 44)
                    .background(.background, in: .capsule)
                    .overlay {
                        Capsule()
                            .stroke(
                                .secondary.opacity(0.45),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                            )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func addTag() {
        store.addTag(newTag)
        newTag = ""
    }
}
