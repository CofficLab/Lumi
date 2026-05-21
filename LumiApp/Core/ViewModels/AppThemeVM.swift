import SwiftUI

/// 主题 ViewModel
///
/// ## 初始化规则
///
/// 由 `RootContainer` 持有并通过 `.environmentObject()` 注入。
/// View 通过 `@EnvironmentObject var themeVM: AppThemeVM` 访问。
/// 主题列表仅来自插件；无贡献时启动失败。默认主题为排序后列表的第一项。
@MainActor
final class AppThemeVM: ObservableObject {

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
        requireSelectedContribution().appTheme
    }

    /// 当前 Editor 主题 ID（贡献中的默认值，明暗适配见 `resolvedEditorThemeId`）
    var activeEditorThemeId: String {
        requireSelectedContribution().editorThemeId
    }

    /// 当前文件树图标主题
    var activeFileIconTheme: (any LumiFileIconThemeContributor)? {
        currentTheme?.fileIconThemeContributor as? any LumiFileIconThemeContributor
    }

    // MARK: - 初始化

    /// 初始化主题 ViewModel，加载保存的主题
    init() {
        let initialThemes = Self.requireThemesFromPlugins()
        self.themes = initialThemes
        self.currentThemeId = Self.requireDefaultThemeId(from: initialThemes)
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
        let loaded = Self.requireThemesFromPlugins()
        themes = loaded
        if !themes.contains(where: { $0.id == currentThemeId }) {
            currentThemeId = Self.requireDefaultThemeId(from: loaded)
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
        let themes = requireThemesFromPlugins()
        if let match = themes.first(where: { $0.id == themeId }) {
            return match.editorThemeId
        }
        return requireDefaultThemeId(from: themes)
    }

    /// 获取当前编辑器主题 ID（用于终端颜色同步）
    ///
    /// 从本地存储读取选中的主题 ID，转换为编辑器主题 ID。
    static func currentEditorThemeId() -> String {
        let themes = requireThemesFromPlugins()
        if let savedThemeId = ThemeStatusBarPluginLocalStore.shared.loadSelectedThemeID(),
           let match = themes.first(where: { $0.id == savedThemeId }) {
            return match.editorThemeId
        }
        return requireDefaultThemeId(from: themes)
    }

    // MARK: - 私有方法

    private func requireSelectedContribution() -> LumiThemeContribution {
        guard let contribution = currentTheme ?? themes.first else {
            Self.fatalNoThemePlugins()
        }
        return contribution
    }

    /// 从插件加载主题贡献列表；无贡献时终止启动
    private static func requireThemesFromPlugins() -> [LumiThemeContribution] {
        let pluginThemes = AppPluginVM.shared.getThemeContributions()
        guard !pluginThemes.isEmpty else {
            fatalNoThemePlugins()
        }
        return pluginThemes
    }

    /// 默认主题 ID = 插件主题列表的第一项
    private static func requireDefaultThemeId(from themes: [LumiThemeContribution]) -> String {
        guard let id = themes.first?.id else {
            fatalNoThemePlugins()
        }
        return id
    }

    private static func fatalNoThemePlugins() -> Never {
        fatalError(
            "No theme contributions from any plugin. Enable at least one theme plugin (e.g. ThemeLumiPlugin)."
        )
    }

    /// 应用当前主题到全局状态
    private func applyCurrentTheme() {
        let selected = requireSelectedContribution()
        Themes.currentTheme = selected.appTheme

        NotificationCenter.default.post(
            name: .lumiThemeDidChange,
            object: nil,
            userInfo: [
                "themeId": selected.id,
                "editorThemeId": selected.editorThemeId,
            ]
        )
    }
}

// MARK: - 预览

#Preview("AppThemeVM") {
    Text("AppThemeVM")
        .environmentObject(AppThemeVM())
}
