import SwiftUI
import LumiUI
import SuperLogKit
import LumiCoreKit

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
public actor ProjectIssueScannerPlugin: SuperPlugin, SuperLog {
    public nonisolated static let emoji = "🔬"
    public nonisolated static let verbose: Bool = true

    public static let id: String = "ProjectIssueScanner"
    public static let displayName: String = "Project Issue Scanner"
    public static let description: String = "Scans for project issues during idle time and hints them to the LLM."
    public static let iconName: String = "scope"
    public static var category: PluginCategory { .developerTool }
    public static var order: Int { 97 }
    public static let policy: PluginPolicy = .disabled

    public static let shared = ProjectIssueScannerPlugin()

    @MainActor
    public func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "项目问题扫描",
                subtitle: "空闲时扫描 TODO、FIXME 和潜在代码问题，并把结果提示给助手。",
                icon: Self.iconName,
                accent: .red,
                metrics: [
                    PluginPosterSupport.metric("Idle", "空闲扫描"),
                    PluginPosterSupport.metric("LLM", "深度分析"),
                ],
                rows: ["本地规则扫描", "LLM 深度分析", "消息上下文提示"],
                chips: ["代码质量", "Agent", "扫描"]
            ),
        ]
    }

    // MARK: - Status Bar

    /// 在状态栏右侧添加问题扫描状态图标。
    @MainActor
    public func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        return AnyView(ProjectIssueScannerStatusBarView())
    }

    // MARK: - Root View

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ProjectIssueScannerRoot(content: content()))
    }

    // MARK: - Send Middleware

    @MainActor
    public func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(IssueHintSendMiddleware())]
    }
}
