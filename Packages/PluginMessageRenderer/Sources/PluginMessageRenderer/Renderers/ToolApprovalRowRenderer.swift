import Foundation
import KitAgentTool
import LumiLoggingKit
import ProviderMessageRendering
import SwiftUI
import os

/// 高风险工具审批的通用行渲染器。
public struct ToolApprovalRowRenderer: ToolCallRowRenderer, SuperLog {
    public static let id = "tool-approval-row"
    public static let priority = 120
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.message-renderer",
        category: "ToolApprovalRowRenderer"
    )

    public init() {}

    public func canRender(toolCall: ToolCall) -> Bool {
        let isPending = toolCall.authorizationState == .pendingAuthorization
        // 兼容旧历史数据：旧流程可能只持久化了最终 result，没有把授权状态
        // 从 pending 改成 userApproved/userRejected。只有仍在等待授权时才展示。
        let isWaitingForAuthorization = toolCall.result == nil || toolCall.result?.awaitingUserResponse == true
        let shouldRender = isPending && isWaitingForAuthorization
        guard shouldRender else { return false }

        // - Important: 载荷必须确实是**授权请求**。
        //   挂起有两种语义：授权（等用户点允许/拒绝）与交互（等用户回答问题，
        //   如 `ask_user`）。两者在消息里的形态几乎一样，只靠 `pendingAuthorization`
        //   无法区分。而交互载荷不是授权载荷——授权卡片构造不出请求，
        //   只会渲染出「无法解析工具审批请求」这句兜底文案。
        //
        //   载荷里的 `kind` 字段是可靠证据（见 `ToolSuspensionKind`）。
        //
        //   - Note: `result == nil` 时无法判别载荷，返回 true 保留旧行为：
        //     由 `render` 按风险等级兜底构造，兼容只落库了状态、没落库载荷的
        //     旧数据。有载荷时则以载荷为准——载荷明确是别的交互（如 `ask_user`）
        //     时绝不能接管，那正是误接管的来源。
        //     「非结构化」的旧载荷（如纯文本）同样保留旧行为：无法判别它是什么，
        //     只能交给风险等级兜底。
        guard let content = toolCall.result?.content else { return true }
        guard ToolSuspensionKind.hasStructuredPayload(content) else { return true }
        return ToolSuspensionKind.isPermissionRequest(content)
    }

    @MainActor
    public func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        guard let request = ToolApprovalBridge.shared.permissionRequest(for: toolCall) else {
            Self.logger.error(
                "\(Self.t)授权渲染器已命中但无法构造授权请求 tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public)"
            )
            return AnyView(Text("无法解析工具审批请求"))
        }

        return AnyView(
            ToolApprovalPendingView(
                request: request,
                toolCall: toolCall,
                conversationID: message.conversationId
            )
        )
    }
}
