//
//  CreateKitItemIdentityFields.swift
//  BagLog
//
//  Created by Eugene Kovs on 25.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct CreateKitItemIdentityFields: View {
    @Binding var item: CreateKitItemDraft
    @Bindable var store: CreateKitStore
    let focus: FocusState<CreateKitFocusField?>.Binding

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                CreateKitItemTextField(
                    title: "Brand",
                    text: $item.brand,
                    focusedField: .itemBrand(item.id),
                    focus: focus,
                    onSubmit: focusModel,
                    valueChanged: store.markTextChanged
                )

                CreateKitItemTextField(
                    title: "Model",
                    text: $item.model,
                    focusedField: .itemModel(item.id),
                    focus: focus,
                    onSubmit: focusNotes,
                    valueChanged: store.markTextChanged
                )
            }

            VStack {
                CreateKitItemTextField(
                    title: "Brand",
                    text: $item.brand,
                    focusedField: .itemBrand(item.id),
                    focus: focus,
                    onSubmit: focusModel,
                    valueChanged: store.markTextChanged
                )

                CreateKitItemTextField(
                    title: "Model",
                    text: $item.model,
                    focusedField: .itemModel(item.id),
                    focus: focus,
                    onSubmit: focusNotes,
                    valueChanged: store.markTextChanged
                )
            }
        }
    }

    private func focusModel() {
        focus.wrappedValue = .itemModel(item.id)
    }

    private func focusNotes() {
        focus.wrappedValue = .itemNotes(item.id)
    }
}
