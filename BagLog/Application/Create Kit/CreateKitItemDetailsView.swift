import SwiftUI

struct CreateKitItemDetailsView: View {
    @Binding var item: CreateKitItemDraft
    @Bindable var store: CreateKitStore
    let focus: FocusState<CreateKitFocusField?>.Binding

    private let categorySuggestions = ["Tech", "Clothing", "Documents", "Tools", "Care"]

    var body: some View {
        VStack(alignment: .leading, spacing: CreateKitDesign.sectionSpacing) {
            TextField("Item name", text: $item.title)
                .font(.title3)
                .bold()
                .submitLabel(.next)
                .focused(focus, equals: .itemTitle(item.id))
                .onSubmit(focusCategory)
                .onChange(of: item.title, store.markTextChanged)

            if item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label("An item name is required", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: CreateKitDesign.cardSpacing) {
                TextField("Category", text: $item.category)
                    .submitLabel(.next)
                    .focused(focus, equals: .itemCategory(item.id))
                    .onSubmit(focusBrand)
                    .onChange(of: item.category, store.markTextChanged)

                ScrollView(.horizontal) {
                    HStack {
                        ForEach(categorySuggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                item.category = suggestion
                                store.markStructureChanged()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    brandField
                    modelField
                }

                VStack {
                    brandField
                    modelField
                }
            }

            Stepper(value: $item.quantity, in: 1...99) {
                LabeledContent("Quantity", value: item.quantity, format: .number)
            }
            .onChange(of: item.quantity, store.markStructureChanged)

            Toggle("Essential item", systemImage: "exclamationmark.circle", isOn: $item.isEssential)
                .onChange(of: item.isEssential, store.markStructureChanged)

            TextField("Notes", text: $item.notes, axis: .vertical)
                .lineLimit(2...6)
                .focused(focus, equals: .itemNotes(item.id))
                .onChange(of: item.notes, store.markTextChanged)

            CreateKitLinksEditor(item: $item, store: store, focus: focus)
        }
    }

    private var brandField: some View {
        TextField("Brand", text: $item.brand)
            .submitLabel(.next)
            .focused(focus, equals: .itemBrand(item.id))
            .onSubmit(focusModel)
            .onChange(of: item.brand, store.markTextChanged)
    }

    private var modelField: some View {
        TextField("Model", text: $item.model)
            .submitLabel(.next)
            .focused(focus, equals: .itemModel(item.id))
            .onSubmit(focusNotes)
            .onChange(of: item.model, store.markTextChanged)
    }

    private func focusCategory() {
        focus.wrappedValue = .itemCategory(item.id)
    }

    private func focusBrand() {
        focus.wrappedValue = .itemBrand(item.id)
    }

    private func focusModel() {
        focus.wrappedValue = .itemModel(item.id)
    }

    private func focusNotes() {
        focus.wrappedValue = .itemNotes(item.id)
    }
}
