import Foundation
import KitAgentTool

/// 工具调用所属对话的项目作用域。
///
/// `IconDocumentStore.shared` 跟随 UI「当前打开的项目」，而当前项目会随
/// **对话切换**改变（见 `PluginProjects/Observers/ConversationProjectSyncObserver`）。
/// 因此对话 A 的工具调用若在用户切到对话 B 之后才取路径，就会写进 B 的项目。
///
/// 宿主在 `ToolExecutionContext` 中提供了本次调用所属对话的项目路径
/// （`conversationProjectPath()`），这里用 TaskLocal 把它带到工具内部，
/// 使路径解析不依赖 UI 状态。
enum IconConversationProjectScope {
    enum Binding: Sendable {
        /// 未绑定项目（或非 Agent 调用），回退到 UI 当前打开的项目。
        case unscoped
        /// 绑定到某个对话的项目路径；`nil` 表示该对话未绑定项目。
        case conversation(projectPath: String?)
    }

    @TaskLocal static var binding: Binding = .unscoped
}

/// 给图标工具套上「对话作用域」，使其按调用所属对话的项目解析存储路径，
/// 而不受 UI 当前选中对话的影响。
///
/// 与 `PluginAppStorePromoDesigner/ConversationScopedPromoTool` 同构。
struct ConversationScopedIconTool: SuperAgentTool {
    private let base: any SuperAgentTool

    init(_ base: any SuperAgentTool) {
        self.base = base
    }

    var name: String { base.name }
    var executionCapability: ToolExecutionCapability { base.executionCapability }

    func description(for language: LanguagePreference) -> String {
        base.description(for: language)
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        base.inputSchema(for: language)
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        base.permissionRiskLevel(arguments: arguments)
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        base.displayDescription(for: arguments)
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await base.execute(arguments: arguments)
    }

    func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        try await base.executeResult(arguments: arguments)
    }

    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        let projectPath = await context.conversationProjectPath()
        return try await IconConversationProjectScope.$binding.withValue(
            .conversation(projectPath: projectPath)
        ) {
            try await base.executeResult(arguments: arguments)
        }
    }
}
