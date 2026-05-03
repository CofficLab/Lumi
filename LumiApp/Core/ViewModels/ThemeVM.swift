import SwiftUI

/// 主题 ViewModel
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
        applyCurrentTheme()

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
        applyCurrentTheme()
    }

    /// 选择指定主题
    ///
    /// - Parameter themeId: 要切换到的主题 ID
    func selectTheme(_ themeId: String) {
        guard themes.contains(where: { $0.id == themeId }) else { return }
        currentThemeId = themeId
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

    /// 解析初始主题 ID
    private static func resolveInitialThemeID(from themes: [LumiThemeContribution]) -> String {
        themes.first?.id ?? LumiBuiltinThemeCatalog.defaultThemeId
    }

    /// 应用当前主题到全局状态
    private func applyCurrentTheme() {
        let selected = currentTheme ?? themes.first
        Themes.currentTheme = selected?.appTheme ?? MidnightTheme()

        let editorThemeId = selected?.editorThemeId ?? "xcode-dark"
        NotificationCenter.default.post(
            name: .lumiThemeDidChange,
            object: nil,
            userInfo: [
                "themeId": selected?.id ?? currentThemeId,
                "editorThemeId": editorThemeId,
            ]
        )
    }
}

// MARK: - 预览

#Preview("ThemeVM") {
    Text("ThemeVM")
        .environmentObject(ThemeVM())
}
