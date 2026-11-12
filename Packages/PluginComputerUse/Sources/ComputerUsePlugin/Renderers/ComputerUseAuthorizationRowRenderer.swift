import Foundation
import KitAgentTool
import ProviderMessageRendering
import SwiftUI

/// Computer Use 授权卡片的行渲染器。
///
/// 只在工具**挂起等待授权**时渲染：结果标记为 `awaitingUserResponse`，
/// 且载荷确实是 Computer Use 授权请求。一旦用户做出决定、工具重新执行
/// 完成，卡片自然消失。
///
/// - Note: 判定**不以 `authorizationState == .pendingAuthorization` 为前提**。
///   授权状态在 LLM 响应阶段就已写定：A3（完全授权）对话下一律是
///   `autoApproved`，而工具可以在执行阶段自己要求用户授权（如 A2 会话里
///   Computer Use 遇到未授权应用）。若强依赖 `pendingAuthorization`，
///   这类挂起就不会画卡片，回合会等一个永远不会到来的回答。
///   载荷本身才是「这是一次 Computer Use 授权请求」的可靠证据。
/// - Note: priority 必须高于通用工具授权卡片（`ToolApprovalRowRenderer`
///   的 120），否则 Computer Use 的授权请求会被通用渲染器抢走，
///   退化成「允许 / 拒绝」两按钮，丢掉「本任务内允许」的语义。
struct ComputerUseAuthorizationRowRenderer: ToolCallRowRenderer {
    static let id = "computer-use-authorization-row"
    static let priority = 200

    private let coordinator: ComputerUseAuthorizationCoordinator

    init(coordinator: ComputerUseAuthorizationCoordinator? = nil) {
        self.coordinator = coordinator ?? .shared
    }

    public func canRender(toolCall: ToolCall) -> Bool {
        // 用户已做出决定后不得再渲染：否则界面会一直等一个已经给出的答案。
        guard toolCall.authorizationState != .userApproved,
              toolCall.authorizationState != .userRejected,
              toolCall.result?.awaitingUserResponse == true,
              let content = toolCall.result?.content
        else { return false }
        // 只有载荷确实是 Computer Use 授权请求时才接管，避免误抢其他挂起卡片。
        return coordinator.request(from: content) != nil
    }

    @MainActor
    public func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        guard let content = toolCall.result?.content,
              let request = coordinator.request(from: content) else {
            return AnyView(Text(""))
        }
        return AnyView(
            ComputerUseAuthorizationCard(
                request: request,
                toolCall: toolCall,
                conversationID: message.conversationId
            )
        )
    }
}
