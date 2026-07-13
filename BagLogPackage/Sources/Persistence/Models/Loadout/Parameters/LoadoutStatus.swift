//
//  LoadoutStatus.swift
//  BagLog
//
//  Created by Eugene Kovs on 11.07.2026.
//  https://github.com/kovs705
//

import Foundation

public enum LoadoutStatus: String, Codable, Sendable {
    case draft
    case published
    case archived
}
