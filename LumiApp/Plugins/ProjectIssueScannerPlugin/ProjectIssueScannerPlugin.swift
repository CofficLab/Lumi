import SwiftUI

/// ProjectIssueScanner 插件
///
/// 在空闲时自动扫描项目中的潜在问题，将发现的问题存储到插件专属目录，
/// 并在用户发送消息时通过中间件将相关问题提示注入给 LLM。
///
/// ## 工作流程
///
/// 1. **LLM 服务获取**：通过 `addRootView` 的 @EnvironmentObject 获取 AppLLMVM。
/// 2. **空闲扫描**：监听 `AppIdleTimeVM.isInRestWindow`，在休息窗口触发扫描。
/// 3. **本地规则扫描**：零成本扫描 TODO/FIXME/空 catch 块等。
/// 4. **LLM 深度分析**：按需调用 LLM 做深度分析（有成本，每日限流）。
/// 5. **问题存储**：结果持久化到插件专属目录的 JSON 文件。
/// 6. **提示注入**：中间件读取未解决问题，注入 `transientSystemPrompts`。
actor ProjectIssueScannerPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🔬"
    nonisolated static let verbose: Bool = true

    static let id: String = "ProjectIssueScanner"
    static let displayName: String = "Project Issue Scanner"
    static let description: String = "Scans for project issues during idle time and hints them to the LLM."
    static let iconName: String = "scope"
    static let isConfigurable: Bool = true
    static let enable: Bool = true
    static var category: PluginCategory { .developerTool }
    static var order: Int { 97 }

    static let shared = ProjectIssueScannerPlugin()

    // MARK: - Status Bar

    /// 在状态栏右侧添加问题扫描状态图标。
    @MainActor
    func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        guard activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(ProjectIssueScannerStatusBarView())
    }

    // MARK: - Root View

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ProjectIssueScannerRoot(content: content()))
    }

    // MARK: - Settings View

    @MainActor
    func addSettingsView() -> AnyView? {
        AnyView(ProjectIssueScannerSettingsView())
    }

    // MARK: - Send Middleware

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(IssueHintSendMiddleware())]
    }
}
