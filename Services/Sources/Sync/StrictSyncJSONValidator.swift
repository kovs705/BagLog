import Foundation

enum StrictSyncJSONValidator {
    static func validateProfile(_ data: Data) throws {
        let object = try jsonObject(data)
        try requireKeys(
            object,
            allowed: [
                "id", "handle", "display_name", "bio", "revision",
                "created_at", "updated_at"
            ],
            required: [
                "id", "handle", "display_name", "revision",
                "created_at", "updated_at"
            ]
        )
    }

    static func validateLoadout(_ data: Data) throws {
        try validateLoadoutObject(jsonObject(data))
    }

    static func validateTombstone(_ data: Data) throws {
        try requireKeys(
            jsonObject(data),
            allowed: ["id", "revision", "deleted_at"],
            required: ["id", "revision", "deleted_at"]
        )
    }

    static func validateBootstrapPage(_ data: Data) throws {
        let object = try dictionary(jsonObject(data))
        try requireKeys(
            object,
            allowed: ["loadouts", "cursor", "next_after", "has_more"],
            required: ["loadouts", "cursor", "next_after", "has_more"]
        )
        guard let loadouts = object["loadouts"] as? [Any] else {
            throw BagLogSyncError.unexpectedResponse
        }
        for loadout in loadouts {
            try validateLoadoutObject(loadout)
        }
    }

    static func validateChangePage(_ data: Data) throws {
        let object = try dictionary(jsonObject(data))
        try requireKeys(
            object,
            allowed: ["changes", "next_cursor", "has_more"],
            required: ["changes", "next_cursor", "has_more"]
        )
        guard let changes = object["changes"] as? [Any] else {
            throw BagLogSyncError.unexpectedResponse
        }
        for change in changes {
            let changeObject = try dictionary(change)
            try requireKeys(
                changeObject,
                allowed: [
                    "cursor", "resource_id", "operation", "revision",
                    "changed_at", "loadout"
                ],
                required: [
                    "cursor", "resource_id", "operation", "revision",
                    "changed_at", "loadout"
                ]
            )
            if let loadout = changeObject["loadout"], !(loadout is NSNull) {
                try validateLoadoutObject(loadout)
            }
        }
    }

    static func validateError(_ data: Data) throws {
        try requireKeys(
            jsonObject(data),
            allowed: ["code", "message", "trace_id"],
            required: ["code", "message", "trace_id"]
        )
    }

    private static func validateLoadoutObject(_ value: Any) throws {
        let object = try dictionary(value)
        try requireKeys(
            object,
            allowed: [
                "id", "title", "summary", "category", "items", "tags",
                "revision", "created_at", "updated_at"
            ],
            required: [
                "id", "title", "summary", "category", "items", "tags",
                "revision", "created_at", "updated_at"
            ]
        )
        guard let items = object["items"] as? [Any] else {
            throw BagLogSyncError.unexpectedResponse
        }
        for item in items {
            try validateItemObject(item)
        }
    }

    private static func validateItemObject(_ value: Any) throws {
        let object = try dictionary(value)
        try requireKeys(
            object,
            allowed: [
                "id", "title", "category", "brand", "model", "notes",
                "quantity", "is_essential", "links"
            ],
            required: ["id", "title", "quantity", "is_essential", "links"]
        )
        guard let links = object["links"] as? [Any] else {
            throw BagLogSyncError.unexpectedResponse
        }
        for link in links {
            try requireKeys(
                link,
                allowed: ["id", "url", "label"],
                required: ["id", "url"]
            )
        }
    }

    private static func requireKeys(
        _ value: Any,
        allowed: Set<String>,
        required: Set<String>
    ) throws {
        let object = try dictionary(value)
        let keys = Set(object.keys)
        guard keys.isSubset(of: allowed), required.isSubset(of: keys) else {
            throw BagLogSyncError.unexpectedResponse
        }
    }

    private static func dictionary(_ value: Any) throws -> [String: Any] {
        guard let dictionary = value as? [String: Any] else {
            throw BagLogSyncError.unexpectedResponse
        }
        return dictionary
    }

    private static func jsonObject(_ data: Data) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            throw BagLogSyncError.unexpectedResponse
        }
    }
}
