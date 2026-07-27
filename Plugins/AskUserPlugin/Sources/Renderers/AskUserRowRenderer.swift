import AgentToolKit
import Foundation
import LumiKernel
import SwiftUI

/// AskUser 的 ToolCall 行级渲染器
///
/// 当 `ask_user` 工具处于 `awaitingUserResponse` 状态时，
/// 替代默认的 `ToolCallRow`，渲染用户选择界面。
///
/// 通过 `ToolCallRowRendererRegistry` 注册到 `MessageRendererPlugin`，
/// 无需插件间直接依赖。
///
/// 根据 `verbosity` 渲染不同详细程度：
/// - `brief` / `v1`: 简洁模式 - 仅问题 + 是/否按钮
/// - `standard` / `v2` (默认): 标准模式 - 问题 + 选项 + 图标
/// - `detailed` / `v3`: 详细模式 - 问题 + 选项 + 图标 + 元信息 + 自由输入
public struct AskUserRowRenderer: ToolCallRowRenderer {
    public static let id = "ask-user-row"
    public static let priority = 100

    public init() {}

    public func canRender(toolCall: ToolCall) -> Bool {
        toolCall.name == "ask_user"
            && toolCall.result?.awaitingUserResponse == true
    }

    @MainActor
    public func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        // 从 toolCall.result.content 解析 AskUserPendingResponse
        guard let content = toolCall.result?.content,
              let response = Self.parsePendingResponse(from: content) else {
            return AnyView(Text("无法解析问题内容"))
        }

        // 根据 verbosity 字符串路由到不同视图
        switch response.verbosity.lowercased() {
        case "v1", "brief":
            return AnyView(AskUserBriefView(response: response, toolCall: toolCall))
        case "v3", "detailed":
            return AnyView(AskUserDetailedView(response: response, toolCall: toolCall))
        default: // "v2", "standard" 或其他
            return AnyView(AskUserStandardView(response: response, toolCall: toolCall))
        }
    }

    /// 从 `toolCall.result.content` 中解析 `AskUserPendingResponse`。
    ///
    /// 暴露为 `static` 以便在没有 `ToolCall` 的单元测试里复用。
    static func parsePendingResponse(from content: String) -> AskUserPendingResponse? {
        let prefix = "__ASK_USER_PENDING__\n"
        guard content.hasPrefix(prefix) else { return nil }
        let jsonString = content.dropFirst(prefix.count)
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AskUserPendingResponse.self, from: jsonData)
    }
}
