//
//  CKEditorError.swift
//  BagLog
//
//  Created by Eugene Kovs on 24.07.2026.
//  https://github.com/kovs705
//

import Foundation

enum CreateKitEditorError: Error {
    case invalidDraft(String)
    case missingDependency
    case missingProfile
    case unavailableDraft
    case saveFailed
}
