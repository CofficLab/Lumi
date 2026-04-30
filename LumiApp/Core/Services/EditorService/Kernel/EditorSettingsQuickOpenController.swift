import Foundation

@MainActor
struct EditorSettingsQuickOpenController {
    func suggestions(matching query: String) -> [EditorQuickOpenItemSuggestion] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }

        let builtInItems: [EditorQuickOpenItemSuggestion] = EditorSettingsCatalog.builtInSections().reduce(into: []) { result, section in
            let items = section.entries.compactMap { entry -> EditorQuickOpenItemSuggestion? in
                guard matches(query: normalizedQuery, title: entry.title, subtitle: entry.subtitle, keywords: entry.keywords, section: section.title) else {
                    return nil
                }
                return makeSuggestion(
                    id: entry.id,
                    title: entry.title,
                    subtitle: entry.subtitle ?? section.title,
                    badge: section.title,
                    searchQuery: normalizedQuery
                )
            }
            result.append(contentsOf: items)
        }

        let contributedItems: [EditorQuickOpenItemSuggestion] = EditorSettingsState.shared.contributedSettings.compactMap { item in
            guard matches(
                query: normalizedQuery,
                title: item.title,
                subtitle: item.subtitle,
                keywords: item.keywords,
                section: item.sectionTitle
            ) else {
                return nil
            }
            return makeSuggestion(
                id: item.id,
                title: item.title,
                subtitle: item.subtitle ?? item.sectionTitle,
                badge: item.sectionTitle,
                searchQuery: normalizedQuery
            )
        }

        return (builtInItems + contributedItems).sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    private func makeSuggestion(
        id: String,
        title: String,
        subtitle: String,
        badge: String,
        searchQuery: String
    ) -> EditorQuickOpenItemSuggestion {
        return EditorQuickOpenItemSuggestion(
            id: "setting.\(id)",
            sectionTitle: "Settings",
            title: title,
            subtitle: subtitle,
            systemImage: "slider.horizontal.3",
            badge: badge,
            order: 5,
            isEnabled: true,
            metadata: .init(priority: 60, dedupeKey: id),
            action: {
                AppSettingStore.saveSettingsSelection(type: "core", value: SettingTab.editor.rawValue)
                AppSettingStore.savePendingEditorSettingsSearchQuery(searchQuery)
                NotificationCenter.postOpenSettings()
            }
        )
    }

    private func matches(
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
