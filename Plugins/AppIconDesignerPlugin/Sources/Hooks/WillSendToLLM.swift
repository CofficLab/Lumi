import Foundation
import KernelLumi

/// AppIconDesigner 插件 willSendToLLM 钩子
///
/// 在 AgentTurnRunner 构造 LumiLLMRequest 之前被调用，
/// 将 App Icon Designer 的使用指南作为 system 消息注入到 messages 首位，
/// 引导 Agent 正确使用工具链（含双作用域存储与 preview/review 循环）。
@MainActor
public struct IconDesignerWillSendToLLMHook {
    public init() {}

    /// 执行 willSendToLLM 钩子
    public func execute(
        kernel: KernelLumi,
        messages: [LumiChatMessage]
    ) async -> [LumiChatMessage] {
        guard let conversationID = messages.last?.conversationID else { return messages }

        let guidance = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: """
            App Icon Designer manages its own icon document library across two storage scopes. Every tool accepts an optional `scope` ('project' for the current project's `.lumi/app-icon-designer` folder, or 'app' for the application data directory) and an optional `documentId`; when they are omitted, the currently selected document in the default scope is used. The default scope is 'project' when a project is open, otherwise 'app'. Call list_icon_documents to enumerate documents in either scope.

            For every user request to design an app icon: call create_icon_document (or apply_icon_preset) once, then build the artwork with add_icon_shape, update_icon_shape, update_icon_layer, and set_icon_background. These tools operate on vector shapes — never reference remote resources or external images. After each meaningful edit, call preview_icon and inspect its attached PNG. To get a senior icon designer's perspective before finalizing, call review_icon to receive structured critique and concrete revision suggestions, then iterate. Validate export readiness with lint_icon_document. Source documents stay in plugin-managed storage; export to a user-chosen output directory only at the end with export_icon_svg or export_app_icon.
            """
        )

        return [guidance] + messages
    }
}
