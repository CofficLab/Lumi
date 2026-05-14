import Foundation

public struct EditorSettingsQuickOpenSearchItem: Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let keywords: [String]
    public let sectionTitle: String

    public init(
        id: String,
        title: String,
        subtitle: String?,
        keywords: [String],
        sectionTitle: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.keywords = keywords
        self.sectionTitle = sectionTitle
    }
}

@MainActor
public enum EditorSettingsQuickOpenPolicy {
    public static func matchingItems(
        _ items: [EditorSettingsQuickOpenSearchItem],
        query: String
    ) -> [EditorSettingsQuickOpenSearchItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }

        return items.filter {
            matches(
                query: normalizedQuery,
                title: $0.title,
                subtitle: $0.subtitle,
                keywords: $0.keywords,
                section: $0.sectionTitle
            )
        }
        .sorted { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    public static func matches(
        query: String,
        title: String,
        subtitle: String?,
        keywords: [String],
        section: String
    ) -> Bool {
        let haystack = ([title, subtitle ?? "", section] + keywords).joined(separator: " ")
        return haystack.localizedCaseInsensitiveContains(query)
    }
}
