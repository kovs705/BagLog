//
//  CKSaveState.swift
//  BagLog
//
//  Created by Eugene Kovs on 24.07.2026.
//  https://github.com/kovs705
//

enum CreateKitSaveState: Equatable {
    case idle
    case saving
    case saved
    case failed
}
