import Foundation
import Persistence

struct ProfileWriteDTO: Encodable {
    let handle: String
    let displayName: String
    let bio: String?

    enum CodingKeys: String, CodingKey {
        case handle
        case displayName = "display_name"
        case bio
    }
}

struct ProfileDTO: Decodable {
    let id: UUID
    let handle: String
    let displayName: String
    let bio: String?
    let revision: Int64
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case handle
        case displayName = "display_name"
        case bio
        case revision
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct LoadoutLinkDTO: Codable {
    let id: UUID
    let url: String
    let label: String?

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case label
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        if let label {
            try container.encode(label, forKey: .label)
        } else {
            try container.encodeNil(forKey: .label)
        }
    }
}

struct LoadoutItemDTO: Codable {
    let id: UUID
    let title: String
    let category: String?
    let brand: String?
    let model: String?
    let notes: String?
    let quantity: Int
    let isEssential: Bool
    let links: [LoadoutLinkDTO]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case category
        case brand
        case model
        case notes
        case quantity
        case isEssential = "is_essential"
        case links
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(category, forKey: .category)
        try container.encode(brand, forKey: .brand)
        try container.encode(model, forKey: .model)
        try container.encode(notes, forKey: .notes)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(isEssential, forKey: .isEssential)
        try container.encode(links, forKey: .links)
    }
}

struct LoadoutWriteDTO: Codable {
    let id: UUID
    let title: String
    let summary: String
    let category: String
    let items: [LoadoutItemDTO]
    let tags: [String]
}

struct LoadoutDTO: Decodable {
    let id: UUID
    let title: String
    let summary: String
    let category: String
    let items: [LoadoutItemDTO]
    let tags: [String]
    let revision: Int64
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case category
        case items
        case tags
        case revision
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct LoadoutTombstoneDTO: Decodable {
    let id: UUID
    let revision: Int64
    let deletedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case revision
        case deletedAt = "deleted_at"
    }
}

struct BootstrapPageDTO: Decodable {
    let loadouts: [LoadoutDTO]
    let cursor: Int64
    let nextAfter: UUID?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case loadouts
        case cursor
        case nextAfter = "next_after"
        case hasMore = "has_more"
    }
}

struct LoadoutChangeDTO: Decodable {
    let cursor: Int64
    let resourceID: UUID
    let operation: String
    let revision: Int64
    let changedAt: Date
    let loadout: LoadoutDTO?

    enum CodingKeys: String, CodingKey {
        case cursor
        case resourceID = "resource_id"
        case operation
        case revision
        case changedAt = "changed_at"
        case loadout
    }
}

struct ChangePageDTO: Decodable {
    let changes: [LoadoutChangeDTO]
    let nextCursor: Int64
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case changes
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

struct BackendErrorDTO: Decodable {
    let code: String
    let traceID: String

    enum CodingKeys: String, CodingKey {
        case code
        case traceID = "trace_id"
    }
}

extension LoadoutSyncProjection {
    var transportDTO: LoadoutWriteDTO {
        LoadoutWriteDTO(
            id: id,
            title: title,
            summary: summary,
            category: category,
            items: items.map(\.transportDTO),
            tags: tags
        )
    }
}

private extension LoadoutSyncItem {
    var transportDTO: LoadoutItemDTO {
        LoadoutItemDTO(
            id: id,
            title: title,
            category: category,
            brand: brand,
            model: model,
            notes: notes,
            quantity: quantity,
            isEssential: isEssential,
            links: links.map(\.transportDTO)
        )
    }
}

private extension LoadoutSyncLink {
    var transportDTO: LoadoutLinkDTO {
        LoadoutLinkDTO(id: id, url: urlString, label: label)
    }
}
