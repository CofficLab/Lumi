import Foundation

@MainActor
struct EditorSettingsQuickOpenController {
    func suggestions(matching query: String) -> [EditorQuickOpenItemSuggestion] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = EditorSettingsQuickOpenPolicy.matchingItems(searchItems(), query: normalizedQuery)
        return matches.enumerated().map { index, item in
            makeSuggestion(
                id: item.id,
                title: item.title,
                subtitle: item.subtitle ?? item.sectionTitle,
                badge: item.sectionTitle,
                searchQuery: normalizedQuery,
                order: index
            )
        }
    }

    private func makeSuggestion(
        id: String,
        title: String,
        subtitle: String,
        badge: String,
        searchQuery: String,
        order: Int
    ) -> EditorQuickOpenItemSuggestion {
        return EditorQuickOpenItemSuggestion(
            id: "setting.\(id)",
            sectionTitle: "Settings",
            title: title,
            subtitle: subtitle,
            systemImage: "slider.horizontal.3",
            badge: badge,
            order: order,
            isEnabled: true,
            metadata: .init(priority: 60, dedupeKey: id),
            action: {
                AppSettingStore.saveSettingsSelection(type: "core", value: SettingTab.editor.rawValue)
                AppSettingStore.savePendingEditorSettingsSearchQuery(searchQuery)
                NotificationCenter.postOpenSettings()
            }
        )
    }

    private func searchItems() -> [EditorSettingsQuickOpenSearchItem] {
        let builtInItems = EditorSettingsCatalog.builtInSections().flatMap { section in
            section.entries.map { entry in
                EditorSettingsQuickOpenSearchItem(
                    id: entry.id,
                    title: entry.title,
                    subtitle: entry.subtitle,
                    keywords: entry.keywords,
                    sectionTitle: section.title
                )
            }
        }

        let contributedItems = EditorSettingsState.shared.contributedSettings.map { item in
            EditorSettingsQuickOpenSearchItem(
                id: item.id,
                title: item.title,
                subtitle: item.subtitle,
                keywords: item.keywords,
                sectionTitle: item.sectionTitle
            )
        }

        return builtInItems + contributedItems
    }
}
