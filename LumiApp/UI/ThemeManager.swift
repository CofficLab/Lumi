import SwiftUI

// MARK: - 主题切换器（用于预览和设置）
///
/// 管理应用主题的 ObservableObject，支持主题切换和持久化
///
@MainActor
class ThemeManager: ObservableObject {
    /// 全部主题（由插件注入）
    @Published private(set) var themes: [LumiThemeContribution] = []

    /// 当前选中的主题 ID
    @Published var currentThemeId: String {
        didSet {
            guard oldValue != currentThemeId else { return }
            applyCurrentTheme()
        }
    }

    /// 当前选中的主题
    var currentTheme: LumiThemeContribution? {
        themes.first(where: { $0.id == currentThemeId })
    }

    /// 当前 App 主题对象
    var activeAppTheme: any ThemeProtocol {
        currentTheme?.appTheme ?? MidnightTheme()
    }

    /// 当前 Editor 主题 ID
    var activeEditorThemeId: String {
        currentTheme?.editorThemeId ?? "xcode-dark"
    }

    /// 是否启用高对比度模式
    @Published var isHighContrast: Bool = false {
        didSet {
            Themes.isHighContrast = isHighContrast
        }
    }

    /// 初始化主题管理器，加载保存的主题
    init() {
        let initialThemes = Self.loadThemesFromPlugins()
        self.themes = initialThemes
        self.currentThemeId = Self.resolveInitialThemeID(from: initialThemes)
        applyCurrentTheme(shouldSave: false)

        NotificationCenter.default.addObserver(
            forName: .pluginsDidLoad,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reloadThemes()
            }
        }
    }

    func reloadThemes() {
        let loaded = Self.loadThemesFromPlugins()
        themes = loaded
        if !themes.contains(where: { $0.id == currentThemeId }) {
            currentThemeId = themes.first?.id ?? LumiBuiltinThemeCatalog.defaultThemeId
            return
        }
        applyCurrentTheme(shouldSave: false)
    }

    func selectTheme(_ themeId: String) {
        guard themes.contains(where: { $0.id == themeId }) else { return }
        currentThemeId = themeId
    }

    static func loadSavedThemeId() -> String? {
        if let value = ThemeVariantStateStore.loadString(forKey: LumiBuiltinThemeCatalog.selectedThemeKey), !value.isEmpty {
            return value
        }
        // 兼容旧版本保存键
        if let legacy = ThemeVariantStateStore.loadString(forKey: LumiBuiltinThemeCatalog.legacySelectedThemeKey), !legacy.isEmpty {
            return legacy
        }
        return nil
    }

    static func editorThemeID(for themeId: String) -> String {
        let themes = loadThemesFromPlugins()
        return themes.first(where: { $0.id == themeId })?.editorThemeId ?? "xcode-dark"
    }

    private static func loadThemesFromPlugins() -> [LumiThemeContribution] {
        let pluginThemes = PluginVM.shared.getThemeContributions()
        if !pluginThemes.isEmpty {
            return pluginThemes
        }
        return LumiBuiltinThemeCatalog.themes()
    }

    private static func resolveInitialThemeID(from themes: [LumiThemeContribution]) -> String {
        let saved = loadSavedThemeId() ?? LumiBuiltinThemeCatalog.defaultThemeId
        if themes.contains(where: { $0.id == saved }) {
            return saved
        }
        return themes.first?.id ?? LumiBuiltinThemeCatalog.defaultThemeId
    }

    private func applyCurrentTheme(shouldSave: Bool = true) {
        let selected = currentTheme ?? themes.first
        Themes.currentTheme = selected?.appTheme ?? MidnightTheme()

        if shouldSave {
            ThemeVariantStateStore.saveString(currentThemeId, forKey: LumiBuiltinThemeCatalog.selectedThemeKey)
        }

        let editorThemeId = selected?.editorThemeId ?? "xcode-dark"
        NotificationCenter.default.post(
            name: .lumiThemeDidChange,
            object: nil,
            userInfo: [
                "themeId": selected?.id ?? currentThemeId,
                "editorThemeId": editorThemeId,
            ]
        )
        // 兼容现有编辑器/终端监听方
        NotificationCenter.default.post(
            name: .lumiEditorThemeDidChange,
            object: nil,
            userInfo: ["themeId": editorThemeId]
        )
        updateColors()
    }

    private func updateColors() {
        // 更新主题时会自动刷新
        objectWillChange.send()
    }
}

// MARK: - 预览
#Preview("主题管理器") {
    Text("MystiqueThemeManager 单文件预览")
        .mystiqueBackground()
        .environmentObject(ThemeManager())
}
