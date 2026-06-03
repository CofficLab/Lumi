import Foundation
import LumiCoreKit
import AgentToolKit
import SwiftUI

/// ConversationListPlugin 的运行时桥接
///
/// 插件在 SPM 包中无法直接访问 app 层类型（WindowConversationVM、WindowProjectVM 等），
/// 通过静态闭包由 app 层在启动时注入具体实现。
public enum ConversationListRuntime {
    nonisolated(unsafe) public static var databaseDirectoryProvider: () -> URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Lumi", isDirectory: true)
    }

    public static func databaseDirectory() -> URL {
        databaseDirectoryProvider()
    }

    // MARK: - UI Bridge

    /// 工具栏右侧视图提供者
    ///
    /// 返回 `ConversationListPopoverButton`，由 app 层注入。
    /// 仅在编辑器模式下调用。
    @MainActor public static var toolbarTrailingViewProvider: (() -> AnyView)?

    // MARK: - Middleware Bridge

    /// 发送中间件提供者
    ///
    /// 返回包含 `ProjectSwitchSendMiddleware` 的中间件数组。
    @MainActor public static var sendMiddlewaresProvider: (() -> [AnySuperSendMiddleware])?

    // MARK: - Agent Tools Bridge

    /// Agent 工具提供者
    ///
    /// 返回对话管理相关的 Agent 工具（创建/删除/列表/计数/项目关联）。
    @MainActor public static var agentToolsProvider: ((ToolContext) -> [SuperAgentTool])?
}
