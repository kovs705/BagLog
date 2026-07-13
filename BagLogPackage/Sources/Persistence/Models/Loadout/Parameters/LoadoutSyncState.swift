//
//  LoadoutSyncState.swift
//  BagLog
//
//  Created by Eugene Kovs on 11.07.2026.
//  https://github.com/kovs705
//

import Foundation

public enum LoadoutSyncState: String, Codable, Sendable {
    case local
    case pendingUpload
    case synced
    case failed
}
