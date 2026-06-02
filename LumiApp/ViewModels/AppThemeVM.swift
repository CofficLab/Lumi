import Combine
import LumiUI
import ThemeStatusBarPlugin
import SwiftUI

/// 主题 ViewModel：委托 ``LumiUIThemeRegistry``，由 ``ThemeService`` 从插件同步贡献。
@MainActor
final class AppThemeVM: ObservableObject {

    private let registry: LumiUIThemeRegistry
    private let syncThemes: (LumiUIThemeRegistry) -> Void
    private let saveSelectedThemeID: (String) -> Void
    private let postThemeDidChangeNotification: (String, String) -> Void
    private var lastPostedThemeChange: (themeId: String, editorThemeId: String)?
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var themes: [LumiUIThemeContribution] = []

    @Published var currentThemeId: String {
        didSet {
            guard oldValue != currentThemeId else { return }
            applySelection(themeId: currentThemeId)
        }
    }

    var currentTheme: LumiUIThemeContribution? {
        themes.first(where: { $0.id == currentThemeId })
    }

    var activeChromeTheme: any LumiAppChromeTheme {
        requireSelectedContribution().chromeTheme
    }

    var activeEditorThemeId: String {
        requireSelectedContribution().editorThemeId
    }

    var activeFileIconTheme: (any LumiFileIconThemeContributor)? {
        currentTheme?.attachments.fileIconThemeContributor as? any LumiFileIconThemeContributor
    }

    init(
        registry: LumiUIThemeRegistry = .shared,
        syncThemes: @escaping (LumiUIThemeRegistry) -> Void = { ThemeService.shared.syncFromPlugins(registry: $0) },
        loadSelectedThemeID: () -> String? = { ThemeStatusBarPluginLocalStore.shared.loadSelectedThemeID() },
        saveSelectedThemeID: @escaping (String) -> Void = { ThemeStatusBarPluginLocalStore.shared.saveSelectedThemeID($0) },
        postThemeDidChangeNotification: @escaping (String, String) -> Void = { themeId, editorThemeId in
            NotificationCenter.default.post(
                name: .lumiThemeDidChange,
                object: nil,
                userInfo: [
                    "themeId": themeId,
                    "editorThemeId": editorThemeId,
                ]
            )
        }
    ) {
        self.registry = registry
        self.syncThemes = syncThemes
        self.saveSelectedThemeID = saveSelectedThemeID
        self.postThemeDidChangeNotification = postThemeDidChangeNotification
        syncThemes(registry)
        if registry.themes.isEmpty {
            try? registry.replaceAll([LumiUIThemeContribution.builtInFallback()])
        }
        let initialId = Self.initialSelectedId(registry: registry, savedThemeId: loadSelectedThemeID())
        if registry.selectedThemeId != initialId {
            try? registry.select(themeId: initialId)
        }
        self.themes = registry.themes
        self.currentThemeId = initialId
        bindRegistry()
        bindPluginLoadNotifications()
    }

    func reloadThemes() {
        syncThemes(registry)
        syncPublishedStateFromRegistry(preserveSelection: true)
    }

    /// 系统明暗变化时，刷新跟随外观的 chrome / LumiUI 组件主题缓存。
    func refreshAppearanceDependentChrome() {
        guard activeChromeTheme.followsSystemAppearance else { return }
        do {
            try registry.select(themeId: currentThemeId)
        } catch {
            return
        }
        postThemeDidChange()
    }

    @discardableResult
    func selectTheme(_ themeId: String) -> Bool {
        guard themes.contains(where: { $0.id == themeId }) else { return false }
        if currentThemeId != themeId {
            currentThemeId = themeId
        }
        return true
    }

    static func editorThemeID(for themeId: String, registry: LumiUIThemeRegistry = .shared) -> String {
        let themes = registry.themes
        if let match = themes.first(where: { $0.id == themeId }) {
            return match.editorThemeId
        }
        if let defaultThemeId = try? registry.defaultThemeId(),
           let fallback = themes.first(where: { $0.id == defaultThemeId }) {
            return fallback.editorThemeId
        }
        return themeId
    }

    static func currentEditorThemeId() -> String {
        let registry = LumiUIThemeRegistry.shared
        let themes = registry.themes
        if let savedThemeId = ThemeStatusBarPluginLocalStore.shared.loadSelectedThemeID(),
           let match = themes.first(where: { $0.id == savedThemeId }) {
            return match.editorThemeId
        }
        if let defaultThemeId = try? registry.defaultThemeId(),
           let fallback = themes.first(where: { $0.id == defaultThemeId }) {
            return fallback.editorThemeId
        }
        return ""
    }

    // MARK: - Private

    private func bindRegistry() {
        registry.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncPublishedStateFromRegistry(preserveSelection: true)
            }
            .store(in: &cancellables)
    }

    private func bindPluginLoadNotifications() {
        NotificationCenter.default.publisher(for: .pluginsDidLoad)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadThemes()
            }
            .store(in: &cancellables)
    }

    private func syncPublishedStateFromRegistry(preserveSelection: Bool) {
        themes = registry.themes
        guard let selectedId = registry.selectedThemeId else { return }
        if preserveSelection, themes.contains(where: { $0.id == currentThemeId }) {
            postThemeDidChange()
            return
        }
        if currentThemeId != selectedId {
            currentThemeId = selectedId
        } else {
            postThemeDidChange()
        }
    }

    private func applySelection(themeId: String) {
        do {
            try registry.select(themeId: themeId)
        } catch {
            return
        }
        postThemeDidChange()
    }

    private func requireSelectedContribution() -> LumiUIThemeContribution {
        if let contribution = currentTheme ?? themes.first {
            return contribution
        }
        return .builtInFallback()
    }

    private static func requireSelectedId(registry: LumiUIThemeRegistry) -> String {
        guard let id = registry.selectedThemeId else {
            return LumiUIThemeContribution.builtInFallback().id
        }
        return id
    }

    static func initialSelectedId(registry: LumiUIThemeRegistry, savedThemeId: String?) -> String {
        let themes = registry.themes
        if let savedThemeId, themes.contains(where: { $0.id == savedThemeId }) {
            return savedThemeId
        }
        return requireSelectedId(registry: registry)
    }

    private func postThemeDidChange() {
        guard let selected = currentTheme ?? themes.first else { return }
        let colorScheme = SystemAppearanceResolver.effectiveColorScheme
        let editorThemeId = selected.chromeTheme.resolvedEditorThemeId(
            defaultEditorThemeId: selected.editorThemeId,
            colorScheme: colorScheme
        )
        let themeChange = (themeId: selected.id, editorThemeId: editorThemeId)
        guard lastPostedThemeChange?.themeId != themeChange.themeId ||
            lastPostedThemeChange?.editorThemeId != themeChange.editorThemeId
        else { return }

        lastPostedThemeChange = themeChange
        saveSelectedThemeID(selected.id)
        postThemeDidChangeNotification(selected.id, editorThemeId)
    }
}

// MARK: - 预览

#Preview("AppThemeVM") {
    Text("AppThemeVM")
        .environmentObject(AppThemeVM())
}
