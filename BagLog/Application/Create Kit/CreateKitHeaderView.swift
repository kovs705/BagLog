import Persistence
import SwiftUI

struct CreateKitHeaderView: View {
    @Binding var draft: CreateKitDraft
    @Bindable var store: CreateKitStore
    let focus: FocusState<CreateKitFocusField?>.Binding
    let accessibilityTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: CreateKitDesign.sectionSpacing) {
            Text("KIT IN PROGRESS")
                .font(.headline)
                .foregroundStyle(.orange)
                .accessibilityLabel(accessibilityTitle)
                .accessibilityAddTraits(.isHeader)

            TextField(
                "Name this kit",
                text: $draft.title,
                prompt: Text("Name this kit").foregroundStyle(.white.opacity(0.62)),
                axis: .vertical
            )
                .font(.largeTitle.scaled(by: 1.35))
                .bold()
                .foregroundStyle(.white)
                .tint(.orange)
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
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.82), in: .capsule)
            }

            TextField(
                "What is this kit for? Add a short note that makes it useful later.",
                text: $draft.summary,
                prompt: Text("What is this kit for? Add a short useful note.")
                    .foregroundStyle(.white.opacity(0.62)),
                axis: .vertical
            )
            .font(.body)
            .foregroundStyle(.white)
            .tint(.orange)
            .lineLimit(2...6)
            .focused(focus, equals: .summary)
            .onChange(of: draft.summary, store.markTextChanged)

            Picker(selection: $draft.category) {
                ForEach(LoadoutCategory.allCases, id: \.self) { category in
                    Label(category.createKitTitle, systemImage: category.createKitSymbol)
                        .tag(category)
                }
            } label: {
                Label(draft.category.createKitTitle, systemImage: draft.category.createKitSymbol)
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(.black.opacity(0.34), in: .capsule)
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.54), lineWidth: 1)
                    }
            }
            .pickerStyle(.menu)
            .tint(.white)
            .onChange(of: draft.category, store.markStructureChanged)
            .accessibilityLabel("Kit category")
        }
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
