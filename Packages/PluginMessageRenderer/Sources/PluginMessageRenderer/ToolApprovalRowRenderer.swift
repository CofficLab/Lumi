import Foundation
import KernelCore
import KitAgentTool
import LumiUI
import ProviderAgentLoop
import ProviderMessageRendering
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

    private init() {}

    func start(kernel: KernelCoreContainer) {
        agentLoop = kernel.resolveProvider((any AgentLoopProviding).self)
    }

    func stop() {
        agentLoop = nil
    }

    func resume(conversationID: UUID, toolCallID: String, answer: String) {
        guard let agentLoop else { return }
        Task { @MainActor in
            _ = try? await agentLoop.resumeTurn(
                in: conversationID,
                request: AgentTurnResumeRequest(
                    suspensionID: "userInput:\(toolCallID)",
                    answer: answer
                )
            )
        }
    }
}

/// 高风险工具审批的通用行渲染器。
public struct ToolApprovalRowRenderer: ToolCallRowRenderer {
    public static let id = "tool-approval-row"
    public static let priority = 120

    public init() {}

    public func canRender(toolCall: ToolCall) -> Bool {
        guard toolCall.result?.awaitingUserResponse == true,
              let content = toolCall.result?.content,
              let data = content.data(using: .utf8),
              let request = try? JSONDecoder().decode(ToolPermissionRequest.self, from: data) else {
            return false
        }
        return request.kind == "permission"
    }

    @MainActor
    public func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        guard let content = toolCall.result?.content,
              let request = try? JSONDecoder().decode(
                  ToolPermissionRequest.self,
                  from: Data(content.utf8)
              ) else {
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

            HStack(spacing: 8) {
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
        ToolApprovalBridge.shared.resume(
            conversationID: conversationID,
            toolCallID: toolCall.id,
            answer: answer
        )
    }
}
