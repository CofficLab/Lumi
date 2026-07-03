import LumiCoreKit
import LumiUI
import SuperLogKit
import SwiftUI
import os

@MainActor
final class LumiUIService: ObservableObject, LumiThemeServicing, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.lumi-ui")
    nonisolated static let emoji = "🎨"
    nonisolated static let verbose = true

    let themeRegistry: LumiUIThemeRegistry
    private let selectionStore: ThemeSelectionStore
    var onThemesDidChange: (() -> Void)?

    init(
        pluginService: PluginService,
        themeRegistry: LumiUIThemeRegistry = .shared,
        selectionStoreDirectory: URL? = nil
    ) {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化 LumiUIService")
        }

        self.themeRegistry = themeRegistry
        self.selectionStore = ThemeSelectionStore(
            pluginDirectory: selectionStoreDirectory ?? LumiCore.pluginDataDirectory(for: "LumiUI")
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ LumiUIService 初始化完成")
            Self.logger.info("\(Self.t)重载主题")
        }
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
        if Self.verbose {
            Self.logger.info("\(Self.t)从插件服务重载主题贡献")
        }

        let contributions = pluginService.themeContributions()
        let registryContributions = contributions.isEmpty ? [.builtInFallback()] : contributions

        if Self.verbose {
            Self.logger.info("\(Self.t)主题贡献数量: \(registryContributions.count)")
        }

        do {
            try themeRegistry.replaceAll(registryContributions)
            restoreSavedThemeIfPossible()
            onThemesDidChange?()

            if Self.verbose {
                Self.logger.info("\(Self.t)✅ 主题重载完成")
            }
        } catch {
            Self.logger.error("\(Self.t)主题重载失败: \(error.localizedDescription)")
            try? themeRegistry.replaceAll([.builtInFallback()])
            assertionFailure("Failed to register LumiUI themes: \(error)")
            onThemesDidChange?()
        }
    }

    func selectTheme(id: String) throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)选择主题: \(id)")
        }

        try themeRegistry.select(themeId: id)
        selectionStore.saveSelectedThemeID(id)
        onThemesDidChange?()
    }

    private func restoreSavedThemeIfPossible() {
        guard let savedThemeID = selectionStore.loadSelectedThemeID(),
              themeRegistry.themes.contains(where: { $0.id == savedThemeID })
        else {
            if Self.verbose {
                Self.logger.info("\(Self.t)未找到保存的主题或主题不存在，使用默认主题")
            }
            return
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)恢复保存的主题: \(savedThemeID)")
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
