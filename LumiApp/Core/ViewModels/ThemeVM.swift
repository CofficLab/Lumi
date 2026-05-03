import SwiftUI

/// 主题 ViewModel
///
/// 管理应用主题的切换和持久化，统一控制 App 主题和编辑器主题。
/// 通过 SwiftUI 环境注入到视图树中，供所有视图和插件使用。
@MainActor
final class ThemeVM: ObservableObject {

    // MARK: - 属性

    /// 全部主题（由插件注入）
    @Published private(set) var themes: [LumiThemeContribution] = []

    /// 当前选中的主题 ID
    @Published var currentThemeId: String {
        didSet {
            guard oldValue != currentThemeId else { return }
            applyCurrentTheme()
        }
    }

    /// 是否启用高对比度模式
    @Published var isHighContrast: Bool = false {
        didSet {
            Themes.isHighContrast = isHighContrast
        }
    }

    // MARK: - 计算属性

    /// 当前选中的主题
    var currentTheme: LumiThemeContribution? {
        themes.first(where: { $0.id == currentThemeId })
    }

    /// 当前 App 主题对象
    var activeAppTheme: any SuperTheme {
        currentTheme?.appTheme ?? MidnightTheme()
    }

    /// 当前 Editor 主题 ID
    var activeEditorThemeId: String {
        currentTheme?.editorThemeId ?? "xcode-dark"
    }

    // MARK: - 初始化

    /// 初始化主题 ViewModel，加载保存的主题
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

    // MARK: - 公开方法

    /// 重新加载所有主题（插件加载完成后调用）
    func reloadThemes() {
        let loaded = Self.loadThemesFromPlugins()
        themes = loaded
        if !themes.contains(where: { $0.id == currentThemeId }) {
            currentThemeId = themes.first?.id ?? LumiBuiltinThemeCatalog.defaultThemeId
            return
        }
        applyCurrentTheme(shouldSave: false)
    }

    /// 选择指定主题
    ///
    /// - Parameter themeId: 要切换到的主题 ID
    func selectTheme(_ themeId: String) {
        guard themes.contains(where: { $0.id == themeId }) else { return }
        currentThemeId = themeId
    }

    /// 加载已保存的主题 ID
    ///
    /// - Returns: 保存的主题 ID，如果没有则返回 nil
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

    /// 根据主题 ID 获取对应的编辑器主题 ID
    ///
    /// - Parameter themeId: App 主题 ID
    /// - Returns: 编辑器主题 ID
    static func editorThemeID(for themeId: String) -> String {
        let themes = loadThemesFromPlugins()
        return themes.first(where: { $0.id == themeId })?.editorThemeId ?? "xcode-dark"
    }

    // MARK: - 私有方法

    /// 从插件加载主题贡献列表
    private static func loadThemesFromPlugins() -> [LumiThemeContribution] {
        let pluginThemes = PluginVM.shared.getThemeContributions()
        if !pluginThemes.isEmpty {
            return pluginThemes
        }
        return LumiBuiltinThemeCatalog.themes()
    }

    /// 解析初始主题 ID：优先使用已保存的，否则使用默认值
    private static func resolveInitialThemeID(from themes: [LumiThemeContribution]) -> String {
        let saved = loadSavedThemeId() ?? LumiBuiltinThemeCatalog.defaultThemeId
        if themes.contains(where: { $0.id == saved }) {
            return saved
        }
        return themes.first?.id ?? LumiBuiltinThemeCatalog.defaultThemeId
    }

    /// 应用当前主题到全局状态
    ///
    /// - Parameter shouldSave: 是否持久化当前主题选择
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
    }
}

// MARK: - 预览

#Preview("ThemeVM") {
    Text("ThemeVM")
        .environmentObject(ThemeVM())
}
