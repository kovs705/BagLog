//
//  LoadoutCategory.swift
//  BagLog
//
//  Created by Eugene Kovs on 11.07.2026.
//  https://github.com/kovs705
//

import Foundation

public struct LoadoutCategory: RawRepresentable, Hashable, CaseIterable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let everydayCarry = Self(rawValue: "everydayCarry")
    public static let travel = Self(rawValue: "travel")
    public static let cycling = Self(rawValue: "cycling")
    public static let camera = Self(rawValue: "camera")
    public static let work = Self(rawValue: "work")
    public static let outdoor = Self(rawValue: "outdoor")
    public static let emergency = Self(rawValue: "emergency")
    public static let fitness = Self(rawValue: "fitness")
    public static let parenting = Self(rawValue: "parenting")
    public static let other = Self(rawValue: "other")

    public static let allCases: [Self] = [
        .everydayCarry,
        .travel,
        .cycling,
        .camera,
        .work,
        .outdoor,
        .emergency,
        .fitness,
        .parenting,
        .other
    ]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
