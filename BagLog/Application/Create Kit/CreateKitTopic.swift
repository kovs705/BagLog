import Persistence

struct CreateKitTopic: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let symbol: String
    let keywords: [String]

    var category: LoadoutCategory {
        LoadoutCategory(rawValue: id)
    }

    func matches(_ query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return true }

        return title.localizedStandardContains(normalizedQuery)
            || id.localizedStandardContains(normalizedQuery)
            || keywords.contains { $0.localizedStandardContains(normalizedQuery) }
    }

    static func catalog(
        _ topics: [CreateKitTopic],
        including selection: LoadoutCategory
    ) -> [CreateKitTopic] {
        guard !topics.contains(where: { $0.category == selection }) else {
            return topics
        }

        return [
            CreateKitTopic(
                id: selection.rawValue,
                title: selection.createKitTitle,
                symbol: selection.createKitSymbol,
                keywords: []
            )
        ] + topics
    }

    static let bundled = LoadoutCategory.allCases.map { category in
        CreateKitTopic(
            id: category.rawValue,
            title: category.createKitTitle,
            symbol: category.createKitSymbol,
            keywords: []
        )
    }
}
