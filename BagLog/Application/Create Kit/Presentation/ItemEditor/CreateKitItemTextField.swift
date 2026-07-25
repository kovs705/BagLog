//
//  CreateKitItemTextField.swift
//  BagLog
//
//  Created by Eugene Kovs on 25.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct CreateKitItemTextField: View {
    let title: String
    @Binding var text: String
    let focusedField: CreateKitFocusField
    let focus: FocusState<CreateKitFocusField?>.Binding
    let onSubmit: () -> Void
    let valueChanged: () -> Void

    var body: some View {
        TextField(title, text: $text)
            .submitLabel(.next)
            .focused(focus, equals: focusedField)
            .onSubmit(onSubmit)
            .onChange(of: text, valueChanged)
    }
}
