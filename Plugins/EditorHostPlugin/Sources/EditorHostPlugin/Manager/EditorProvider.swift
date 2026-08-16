import Foundation
import SwiftUI
import KernelLumi
import EditorService
import LumiUI
import SuperLogKit

/// Legacy `EditorProviding` 契约实现（迁移期保留）。
///
/// 由 `EditorHostPlugin` 在 OnBoot 创建并立即注入 `EditorService`——
/// 合并宿主后服务在注册前必然就绪，因此不再需要 pending plugin 暂存、
/// 弱引用兜底与 stub 降级路径（见重构方案 §20 Phase 2）。
/// 消费者全部迁移到 `kernel.editorV2` 后整体移除（§26）。
@MainActor
public final class EditorProvider: EditorProviding, SuperLog {
    public static let emoji = "🍚"
    static let verbose: Bool = false

    /// 编辑器子系统门面。由 Host 插件在同一装配事务内注入。
    private let editorService: EditorService

    /// 内核引用,用于在主题变更时解析当前编辑器主题。
    private weak var kernel: KernelLumi?

    /// `.themeDidChange` 订阅令牌,重复绑定时会先移除旧令牌。
    private var themeObserver: NSObjectProtocol?

    public var currentThemeId: String = "default"

    private var themes: [String: EditorThemeInfo] = [:]

    init(service: EditorService) {
        self.editorService = service
    }

    // MARK: - View

    /// 创建编辑器视图（legacy 入口；新消费者使用 `kernel.editorV2.surface`）。
    public func makeEditorView() -> AnyView {
        AnyView(EditorSurfaceView(state: editorService.state))
    }

    // MARK: - File Operations

    public var currentFilePath: String? {
        editorService.files.currentFileURL?.path
    }

    public func openFile(at path: String) async throws {
        let url = URL(fileURLWithPath: path)
        editorService.sessions.open(at: url)
    }

    public func closeFile(at path: String) async {
        let url = URL(fileURLWithPath: path)
        // EditorService 目前没有按 URL 关闭单个 session 的公开 API;
        // 这里以"切到 nil"近似:若关闭的是当前文件,则清空当前 URL。
        if editorService.files.currentFileURL == url {
            editorService.sessions.openFile(at: nil)
        }
    }

    // MARK: - Themes

    public func setCurrentTheme(_ themeId: String) throws {
        guard themes[themeId] != nil else {
            throw KernelLumiError.serviceNotAvailable(service: "Editor theme '\(themeId)' not found")
        }
        currentThemeId = themeId
    }

    public func registerEditorTheme(_ theme: EditorThemeInfo) {
        themes[theme.id] = theme
    }

    public func unregisterEditorTheme(themeId: String) {
        themes.removeValue(forKey: themeId)
    }

    public var allEditorThemes: [EditorThemeInfo] {
        Array(themes.values)
    }

    // MARK: - Theme Sync

    /// 订阅内核 `.themeDidChange` 事件,并在订阅时立即应用一次当前编辑器主题。
    /// ThemeManager 不知道编辑器的存在,只广播事件;这里自行解析并应用。
    func bindThemeSync(kernel: KernelLumi) {
        self.kernel = kernel
        configureEditorThemeContributorRegistration(kernel: kernel)
        applyThemeFromKernel()

        if let previous = themeObserver {
            NotificationCenter.default.removeObserver(previous)
        }
        themeObserver = NotificationCenter.default.addObserver(
            forName: .lumiThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyThemeFromKernel()
        }
    }

    /// 将 Lumi app 主题贡献同步为 EditorService 可解析的语法主题 contributor。
    ///
    /// EditorState 只认识 EditorService 内部的 `SuperEditorThemeContributor`；
    /// ThemeManagerPlugin 切换的是 LumiUI 的 app theme。这里在边界处注册 lifecycle 钩子，
    /// 让每次编辑器主题通知到达时都能用最新 Lumi 主题目录重建 editor syntax 主题。
    private func configureEditorThemeContributorRegistration(kernel: KernelLumi) {
        EditorSettingsLifecycle.registerEditorThemeContributors = { [weak kernel] registry in
            EditorBuiltinSyntaxThemes.registerFallbacks(into: registry)
            guard let themes = kernel?.theme?.themes else { return }
            EditorBuiltinSyntaxThemes.registerAppThemes(themes, into: registry)
        }
    }

    /// 从内核主题注册表解析当前应选用的编辑器主题并应用。
    private func applyThemeFromKernel() {
        guard let registry = kernel?.theme?.themeRegistry else { return }
        guard let editorThemeId = registry.resolvedEditorThemeId(colorScheme: registry.systemColorScheme) else {
            return
        }
        try? setCurrentTheme(editorThemeId)
        // 真正驱动编辑器语法高亮的是 EditorState.currentTheme，它由 EditorHostEnvironment
        // 的 themeDidChange 通知触发刷新（见 EditorConfigController.observeThemeChanges）。
        // ThemeManager 只广播内核事件、不知道 Editor 的存在，因此由本插件在边界处把内核主题
        // 事件桥接为编辑器内部的主题通知，使 EditorState 同步最新的配色。
        postEditorThemeDidChange(editorThemeId)
    }

    private func postEditorThemeDidChange(_ editorThemeId: String) {
        let notificationName = EditorHostEnvironment.current.notifications.themeDidChange
        NotificationCenter.default.post(
            name: notificationName,
            object: nil,
            userInfo: ["editorThemeId": editorThemeId]
        )
    }
}
