import SwiftUI
import LumiUI
import Foundation
import AgentToolKit
import LumiKernel

/// AskUser 的 ToolCall 行级渲染器
///
/// 当 `ask_user` 工具处于 `awaitingUserResponse` 状态时，
/// 替代默认的 `ToolCallRow`，渲染用户选择界面。
///
/// 通过 `ToolCallRowRendererRegistry` 注册到 `MessageRendererPlugin`，
/// 无需插件间直接依赖。
///
/// 根据 `LumiResponseVerbosity` 渲染不同详细程度：
/// - `.brief`: 简洁模式 - 仅问题 + 是/否按钮
/// - `.standard`: 标准模式 - 问题 + 选项 + 图标
/// - `.detailed`: 详细模式 - 问题 + 选项 + 图标 + 元信息 + 自由输入
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
        guard let response = parsePendingResponse(from: toolCall.result?.content ?? "") else {
            return AnyView(Text("无法解析问题内容"))
        }

        // 根据 verbosity 字符串渲染不同视图
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
    /// 暴露为 `static` 是为了在没有 `ToolCall` 的单元测试里也能直接复用。
    static func parsePendingResponse(from content: String) -> AskUserPendingResponse? {
        guard content.hasPrefix(LumiAskUserMarkers.pendingPrefix) else { return nil }
        let header = "\(LumiAskUserMarkers.pendingPrefix)\n"
        let jsonString = content.dropFirst(header.count)
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AskUserPendingResponse.self, from: jsonData)
    }

    private func parsePendingResponse(from content: String) -> AskUserPendingResponse? {
        Self.parsePendingResponse(from: content)
    }
}
