import Foundation

@MainActor
public enum EditorCommandSuggestionPolicy {
    public static func deduplicatingSuggestions(
        _ suggestions: [EditorCommandSuggestion]
    ) -> [EditorCommandSuggestion] {
        var seen = Set<String>()
        let deduplicated = suggestions.filter { suggestion in
            seen.insert(suggestion.id).inserted
        }
        return deduplicated.sortedForCommandPresentation()
    }

    public static func recordExecution(
        id: String,
        recentCommandIDs: inout [String],
        commandUsageCounts: inout [String: Int]
    ) {
        recentCommandIDs.removeAll(where: { $0 == id })
        recentCommandIDs.insert(id, at: 0)
        if recentCommandIDs.count > 12 {
            recentCommandIDs = Array(recentCommandIDs.prefix(12))
        }
        commandUsageCounts[id, default: 0] += 1
    }
}
