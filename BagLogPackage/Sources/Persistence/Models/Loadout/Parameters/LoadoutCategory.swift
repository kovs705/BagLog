//
//  LoadoutCategory.swift
//  BagLog
//
//  Created by Eugene Kovs on 11.07.2026.
//  https://github.com/kovs705
//

import Foundation

public enum LoadoutCategory: String, CaseIterable, Codable, Sendable {
    case everydayCarry
    case travel
    case cycling
    case camera
    case work
    case outdoor
    case emergency
    case fitness
    case parenting
    case other
}
