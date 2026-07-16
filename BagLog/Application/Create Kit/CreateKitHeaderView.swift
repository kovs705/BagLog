import Persistence
import SwiftUI

struct CreateKitHeaderView: View {
    @Binding var draft: CreateKitDraft
    @Bindable var store: CreateKitStore
    let focus: FocusState<CreateKitFocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: CreateKitDesign.cardSpacing) {
            TextField("Name this kit", text: $draft.title, axis: .vertical)
                .font(.largeTitle)
                .bold()
                .lineLimit(1...3)
                .submitLabel(.next)
                .focused(focus, equals: .title)
                .onSubmit(focusComposer)
                .onChange(of: draft.title, titleChanged)
                .accessibilityIdentifier("kit-title")

            if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               store.message != nil {
                Label("A kit title is required", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            TextField(
                "What is this kit for? Add a short note that makes it useful later.",
                text: $draft.summary,
                axis: .vertical
            )
            .font(.body)
            .lineLimit(2...6)
            .focused(focus, equals: .summary)
            .onChange(of: draft.summary, store.markTextChanged)

            Picker("Kit category", selection: $draft.category) {
                ForEach(LoadoutCategory.allCases, id: \.self) { category in
                    Label(category.createKitTitle, systemImage: category.createKitSymbol)
                        .tag(category)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: draft.category, store.markStructureChanged)
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: CreateKitDesign.cardCornerRadius))
        .accessibilityElement(children: .contain)
    }

    private func focusComposer() {
        focus.wrappedValue = .composer
    }

    private func titleChanged(_ oldValue: String, _ newValue: String) {
        if newValue.rangeOfCharacter(from: .newlines) != nil {
            draft.title = newValue
                .components(separatedBy: .newlines)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            focusComposer()
            return
        }
        store.markTextChanged()
    }
}
