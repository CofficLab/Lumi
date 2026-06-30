import LumiCoreKit
import LumiUI
import SwiftUI

@MainActor
final class LumiUIService: ObservableObject, LumiThemeServicing {
    let themeRegistry: LumiUIThemeRegistry
    private let selectionStore: ThemeSelectionStore
    var onThemesDidChange: (() -> Void)?

    init(
        pluginService: PluginService,
        themeRegistry: LumiUIThemeRegistry = .shared,
        selectionStoreDirectory: URL? = nil
    ) {
        self.themeRegistry = themeRegistry
        self.selectionStore = ThemeSelectionStore(
            pluginDirectory: selectionStoreDirectory ?? LumiCore.pluginDataDirectory(for: "LumiUI")
        )
        reloadThemes(from: pluginService)
    }

    var themes: [LumiUIThemeContribution] {
        themeRegistry.themes
    }

    var selectedThemeId: String? {
        themeRegistry.selectedThemeId
    }

    var selectedContribution: LumiUIThemeContribution? {
        themeRegistry.selectedContribution
    }

    func reloadThemes(from pluginService: PluginService) {
        let contributions = pluginService.themeContributions()
        let registryContributions = contributions.isEmpty ? [.builtInFallback()] : contributions

        do {
            try themeRegistry.replaceAll(registryContributions)
            restoreSavedThemeIfPossible()
            onThemesDidChange?()
        } catch {
            try? themeRegistry.replaceAll([.builtInFallback()])
            assertionFailure("Failed to register LumiUI themes: \(error)")
            onThemesDidChange?()
        }
    }

    func selectTheme(id: String) throws {
        try themeRegistry.select(themeId: id)
        selectionStore.saveSelectedThemeID(id)
        onThemesDidChange?()
    }

    private func restoreSavedThemeIfPossible() {
        guard let savedThemeID = selectionStore.loadSelectedThemeID(),
              themeRegistry.themes.contains(where: { $0.id == savedThemeID })
        else {
            return
        }

        try? themeRegistry.select(themeId: savedThemeID)
    }
}

private final class ThemeSelectionStore {
    private let settingsURL: URL

    init(pluginDirectory: URL) {
        self.settingsURL = pluginDirectory.appendingPathComponent("theme-selection.plist")
    }

    func loadSelectedThemeID() -> String? {
        guard let data = try? Data(contentsOf: settingsURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = plist as? [String: String]
        else {
            return nil
        }

        return dictionary["selectedThemeID"]
    }

    @discardableResult
    func saveSelectedThemeID(_ themeID: String) -> Bool {
        let dictionary = ["selectedThemeID": themeID]
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dictionary,
            format: .xml,
            options: 0
        ) else {
            return false
        }

        let settingsURL = self.settingsURL
        Task.detached(priority: .utility) {
            do {
                try FileManager.default.createDirectory(
                    at: settingsURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: settingsURL, options: .atomic)
            } catch {
                // Silently fail for theme save
            }
        }
        return true
    }
}
