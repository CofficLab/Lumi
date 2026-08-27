import Foundation
import KernelCore
import KitAgentTool
import LumiUI
import ProviderAgentLoop
import ProviderMessageRendering
import ProviderToolManager
import SwiftUI

private struct ToolPermissionRequest: Codable {
    let toolCallID: String
    let kind: String
    let question: String
    let options: [String]
    let mode: String

    enum CodingKeys: String, CodingKey {
        case toolCallID = "toolCallId"
        case kind, question, options, mode
    }
}

@MainActor
final class ToolApprovalBridge {
    static let shared = ToolApprovalBridge()

    private weak var agentLoop: (any AgentLoopProviding)?
    private weak var toolManager: (any ToolManagerProviding)?

    private init() {}

    func start(kernel: KernelCoreContainer) {
        agentLoop = kernel.resolveProvider((any AgentLoopProviding).self)
        toolManager = kernel.resolveProvider((any ToolManagerProviding).self)
    }

    func stop() {
        agentLoop = nil
        toolManager = nil
    }

    fileprivate func permissionRequest(for toolCall: ToolCall) -> ToolPermissionRequest? {
        if let content = toolCall.result?.content,
           let request = try? JSONDecoder().decode(
               ToolPermissionRequest.self,
               from: Data(content.utf8)
           ),
           request.kind == "permission" {
            return request
        }
        guard let risk = toolManager?.riskLevel(for: toolCall), risk.requiresPermission else {
            return nil
        }
        return ToolPermissionRequest(
            toolCallID: "approval:\(toolCall.id)",
            kind: "permission",
            question: "此操作被判定为\(risk.displayName)，是否允许执行？\n\(toolManager?.displayDescription(for: toolCall) ?? toolCall.name)",
            options: ["允许", "拒绝"],
            mode: "yes_no"
        )
    }

    func resolve(conversationID: UUID, toolCall: ToolCall, answer: String) {
        guard let toolManager else { return }
        let turnID = agentLoop?.currentTurnID(for: conversationID)
        let approved = Self.isApproval(answer)
        Task { @MainActor in
            if approved {
                _ = await toolManager.executeAuthorized(
                    toolCall,
                    conversationID: conversationID,
                    turnID: turnID
                )
            } else {
                _ = await toolManager.rejectAuthorized(
                    toolCall,
                    conversationID: conversationID,
                    turnID: turnID
                )
            }
        }
    }

    private static func isApproval(_ answer: String) -> Bool {
        switch answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "允许", "同意", "是", "allow", "approve", "approved", "yes":
            return true
        default:
            return false
        }
    }
}

/// 高风险工具审批的通用行渲染器。
public struct ToolApprovalRowRenderer: ToolCallRowRenderer {
    public static let id = "tool-approval-row"
    public static let priority = 120

    public init() {}

    public func canRender(toolCall: ToolCall) -> Bool {
        toolCall.result == nil && toolCall.authorizationState == .pendingAuthorization
    }

    @MainActor
    public func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        guard let request = ToolApprovalBridge.shared.permissionRequest(for: toolCall) else {
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

private struct ToolApprovalPendingView: View {
    @LumiTheme private var theme

    let request: ToolPermissionRequest
    let toolCall: ToolCall
    let conversationID: UUID

    @State private var responded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(theme.primary)
                Text(request.question)
                    .font(.appCaption)
                    .foregroundColor(theme.textPrimary)
            }

            HStack(spacing: 24) {
                ForEach(request.options, id: \.self) { option in
                    Button(option) {
                        submit(option)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(responded)
                }
            }

            if responded {
                Text("已提交：等待继续执行…")
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(12)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.primary.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func submit(_ answer: String) {
        guard !responded else { return }
        responded = true
        ToolApprovalBridge.shared.resolve(
            conversationID: conversationID,
            toolCall: toolCall,
            answer: answer
        )
    }
}
