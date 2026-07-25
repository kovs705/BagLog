//
//  CreateKitStore+PresentationState.swift
//  BagLog
//
//  Created by Eugene Kovs on 25.07.2026.
//  https://github.com/kovs705
//

extension CreateKitStore {
    var canPublish: Bool {
        draft?.canPublish == true && !isPublishing
    }

    var saveStateLabel: String {
        switch saveState {
        case .idle: "Draft"
        case .saving: "Saving"
        case .saved: "Saved"
        case .failed: "Not saved"
        }
    }

    func requestPublish() {
        guard let draft else { return }
        guard draft.canPublish else {
            message = draft.validationMessage ?? "Add at least one item before publishing."
            return
        }

        message = nil
        isShowingPublishConfirmation = true
    }

    func reportPublishFailure(_ error: any Error) {
        guard message == nil else { return }

        if let editorError = error as? CreateKitEditorError,
           case let .invalidDraft(validationMessage) = editorError {
            message = validationMessage
        } else {
            message = "This kit couldn’t be published. Your draft is still here."
        }
    }
}
