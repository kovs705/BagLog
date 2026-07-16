import Foundation

enum CreateKitEditorError: Error {
    case invalidDraft(String)
    case missingDependency
    case missingProfile
    case unavailableDraft
    case saveFailed
}
