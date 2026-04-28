import Foundation

struct EditorCommandPresentationModel {
    let recentCommands: [EditorCommandSuggestion]
    let sections: [EditorCommandSection]

    var flattenedCommands: [EditorCommandSuggestion] {
        recentCommands + sections.flatMap(\.commands)
    }

    static func build(
        from suggestions: [EditorCommandSuggestion],
        recentCommandIDs: [String],
        query: String = "",
        recentLimit: Int = 5,
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

        let suggestionsByID = Dictionary(uniqueKeysWithValues: filteredSuggestions.map { ($0.id, $0) })
        let recentCommands = recentCommandIDs
            .compactMap { suggestionsByID[$0] }
            .prefix(recentLimit)
            .map { $0 }
        let recentIDs = Set(recentCommands.map(\.id))

        let grouped = Dictionary(grouping: filteredSuggestions.filter { !recentIDs.contains($0.id) }) { suggestion in
            EditorCommandCategory(rawValue: suggestion.category ?? "") ?? .other
        }

        let sections = EditorCommandCategory.orderedCases.compactMap { category -> EditorCommandSection? in
            guard let commands = grouped[category], !commands.isEmpty else { return nil }
            let sortedCommands = commands.sortedForCommandPresentation()
            return EditorCommandSection(category: category, commands: sortedCommands)
        }

        return EditorCommandPresentationModel(recentCommands: recentCommands, sections: sections)
    }
}
