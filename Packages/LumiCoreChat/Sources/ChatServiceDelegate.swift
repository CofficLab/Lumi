import Foundation
import LumiCoreAgentTool
import LumiCoreLayout
import LumiCorePlugin

// MARK: - ChatServiceDelegate

/// ChatService 的代理协议，用于解耦 ChatService 与 LumiCoreKit。
///
/// ChatService 通过此协议访问所需的核心功能，而不直接依赖 LumiCoreKit。
/// LumiCore 在创建 ChatService 后通过 `configure(delegate:)` 注入自身。
@MainActor
public protocol ChatServiceDelegate: AnyObject {
    /// Agent 工具功能组件。
    var agentToolComponent: AgentToolComponent { get }

    /// 当前项目路径（如果有的话）。
    var currentProjectPath: String? { get }

    /// 统一创建 `LumiPluginContext`。
    func makePluginContext(
        activeSectionID: String,
        activeSectionTitle: String,
        chatSection: LumiChatSectionLayout,
        showsRail: Bool,
        showsPanelChrome: Bool,
        isChatSectionVisible: Bool?,
        additionalDependencies: (inout LumiPluginDependencies) -> Void
    ) -> LumiPluginContext
}