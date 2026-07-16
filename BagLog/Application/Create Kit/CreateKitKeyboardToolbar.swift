import SwiftUI

struct CreateKitKeyboardToolbar: ToolbarContent {
    @Bindable var store: CreateKitStore
    let focus: FocusState<CreateKitFocusField?>.Binding

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Button("Previous field", systemImage: "chevron.up", action: movePrevious)
                .disabled(!canMovePrevious)
            Button("Next field", systemImage: "chevron.down", action: moveNext)
                .disabled(!canMoveNext)

            Spacer()

            Button("Done", action: dismissKeyboard)
        }
    }

    private func movePrevious() {
        let fields = CreateKitFocusOrder.fields(for: store.draft)
        guard let current = focus.wrappedValue,
              let index = fields.firstIndex(of: current),
              index > fields.startIndex else { return }
        focusField(fields[index - 1])
    }

    private func moveNext() {
        let fields = CreateKitFocusOrder.fields(for: store.draft)
        guard let current = focus.wrappedValue,
              let index = fields.firstIndex(of: current),
              index < fields.index(before: fields.endIndex) else { return }
        focusField(fields[index + 1])
    }

    private func dismissKeyboard() {
        focus.wrappedValue = nil
    }

    private func focusField(_ field: CreateKitFocusField) {
        store.revealField(field)
        focus.wrappedValue = field
    }

    private var canMovePrevious: Bool {
        let fields = CreateKitFocusOrder.fields(for: store.draft)
        guard let current = focus.wrappedValue,
              let index = fields.firstIndex(of: current) else { return false }
        return index > fields.startIndex
    }

    private var canMoveNext: Bool {
        let fields = CreateKitFocusOrder.fields(for: store.draft)
        guard let current = focus.wrappedValue,
              let index = fields.firstIndex(of: current),
              !fields.isEmpty else { return false }
        return index < fields.index(before: fields.endIndex)
    }
}
