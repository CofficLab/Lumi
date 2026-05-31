import Foundation

public struct EditorCommandPresentationModel {
    public let recentCommands: [EditorCommandSuggestion]
    public let frequentCommands: [EditorCommandSuggestion]
    public let sections: [EditorCommandSection]

    public var flattenedCommands: [EditorCommandSuggestion] {
        recentCommands + frequentCommands + sections.flatMap(\.commands)
    }

    public static func build(
        from suggestions: [EditorCommandSuggestion],
        recentCommandIDs: [String],
        commandUsageCounts: [String: Int] = [:],
        query: String = "",
        recentLimit: Int = 5,
        frequentLimit: Int = 5,
        allowedCategories: Set<EditorCommandCategory>? = nil
    ) -> EditorCommandPresentationModel {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryFilteredSuggestions = suggestions.filter { suggestion in
            guard let allowedCategories else { return true }
            let category = EditorCommandCategory(rawValue: suggestion.category ?? "") ?? .other
            return allowedCategories.contains(category)
        }

        let filteredSuggestions = categoryFilteredSuggestions.filter { suggestion in
            guard !normalizedQuery.isEmpty else { return true }
            let categoryValue = suggestion.category ?? ""
            let categoryTitle = EditorCommandCategory(rawValue: categoryValue)?.displayTitle ?? ""
            let shortcutText = suggestion.shortcut?.displayText ?? ""
            return suggestion.title.localizedCaseInsensitiveContains(normalizedQuery)
                || suggestion.id.localizedCaseInsensitiveContains(normalizedQuery)
                || categoryValue.localizedCaseInsensitiveContains(normalizedQuery)
                || categoryTitle.localizedCaseInsensitiveContains(normalizedQuery)
                || shortcutText.localizedCaseInsensitiveContains(normalizedQuery)
        }

        let uniqueSuggestions = deduplicatingSuggestionsPreservingFirst(filteredSuggestions)
        let suggestionsByID = Dictionary(uniqueKeysWithValues: uniqueSuggestions.map { ($0.id, $0) })
        let recentCommands = recentCommandIDs
            .compactMap { suggestionsByID[$0] }
            .prefix(recentLimit)
            .map { $0 }
        let recentIDs = Set(recentCommands.map(\.id))
        let frequentCommands = uniqueSuggestions
            .filter { !recentIDs.contains($0.id) && (commandUsageCounts[$0.id] ?? 0) > 1 }
            .sorted { lhs, rhs in
                let lhsCount = commandUsageCounts[lhs.id] ?? 0
                let rhsCount = commandUsageCounts[rhs.id] ?? 0
                if lhsCount != rhsCount { return lhsCount > rhsCount }
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(frequentLimit)
            .map { $0 }
        let frequentIDs = Set(frequentCommands.map(\.id))

        let grouped = Dictionary(grouping: uniqueSuggestions.filter {
            !recentIDs.contains($0.id) && !frequentIDs.contains($0.id)
        }) { suggestion in
            EditorCommandCategory(rawValue: suggestion.category ?? "") ?? .other
        }

        let sections = EditorCommandCategory.orderedCases.compactMap { category -> EditorCommandSection? in
            guard let commands = grouped[category], !commands.isEmpty else { return nil }
            let sortedCommands = commands.sortedForCommandPresentation()
            return EditorCommandSection(category: category, commands: sortedCommands)
        }

        return EditorCommandPresentationModel(
            recentCommands: recentCommands,
            frequentCommands: frequentCommands,
            sections: sections
        )
    }

    private static func deduplicatingSuggestionsPreservingFirst(
        _ suggestions: [EditorCommandSuggestion]
    ) -> [EditorCommandSuggestion] {
        var seen = Set<String>()
        return suggestions.filter { suggestion in
            seen.insert(suggestion.id).inserted
        }
    }
}
