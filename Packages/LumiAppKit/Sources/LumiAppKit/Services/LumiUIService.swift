import LumiCoreKit
import LumiUI
import SuperLogKit
import SwiftUI
import os

@MainActor
final class LumiUIService: ObservableObject, LumiThemeServicing, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.lumi-ui")
    nonisolated static let emoji = "🎨"
    nonisolated static let verbose = false

    let themeRegistry: LumiUIThemeRegistry
    private let selectionStore: ThemeSelectionStore
    private let pluginService: PluginService
    private var pluginsChangedObserver: NSObjectProtocol?
    var onThemesDidChange: (() -> Void)?

    init(
        pluginService: PluginService,
        lumiCore: LumiCoreAccessing,
        editorCoreService: EditorCoreService? = nil,
        themeRegistry: LumiUIThemeRegistry = .shared,
        selectionStoreDirectory: URL? = nil
    ) {
        self.themeRegistry = themeRegistry
        self.pluginService = pluginService
        self.selectionStore = ThemeSelectionStore(
            pluginDirectory: selectionStoreDirectory ?? lumiCore.pluginDataDirectory(for: "LumiUI")
        )
        reloadThemes(from: pluginService)

        // 主题变更 → 编辑器语法主题同步。原先由 RootContainer 在 boot 后手动接线,
        // 现在收回到 init——editorCoreService 由 RootContainer 显式传入(它是 boot 后
        // 才存在的具体类型),闭包内以弱引用持有避免循环。
        if let editorCoreService {
            connectEditorThemeSync(editorCoreService)
        }

        // 订阅插件启用状态变化,自动重载主题。原先由 RootContainer fan-out 调用,
        // 现在本类自治——和仓库其他 State(LumiProviderState 等)的 NotificationCenter
        // 惯例一致。
        pluginsChangedObserver = NotificationCenter.default.onLumiEnabledPluginsDidChange { [weak self] in
            guard let self else { return }
            self.reloadThemes(from: self.pluginService)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ LumiUIService 初始化完成")
        }
    }

    deinit {
        if let pluginsChangedObserver {
            NotificationCenter.default.removeObserver(pluginsChangedObserver)
        }
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

    /// 把"主题变更"信号接到编辑器语法主题同步。
    ///
    /// 由 init 在收到 `editorCoreService` 参数时调用。`EditorCoreService` 不被
    /// LumiUIService 强持有（仅以弱引用进入闭包），避免循环。
    private func connectEditorThemeSync(_ editorCoreService: EditorCoreService) {
        onThemesDidChange = { [weak editorCoreService] in
            editorCoreService?.syncAppSyntaxThemes()
        }
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
