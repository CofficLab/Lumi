import Foundation
import KernelCore
import KitAgentTool
import KitSuperLog
import LumiUI
import os
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
final class ToolApprovalBridge: SuperLog {
    static let shared = ToolApprovalBridge()
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.message-renderer",
        category: "ToolApprovalBridge"
    )

    private weak var agentLoop: (any AgentLoopProviding)?
    private weak var toolManager: (any ToolManagerProviding)?

    private init() {}

    func start(kernel: KernelCoreContainer) {
        agentLoop = kernel.resolveProvider((any AgentLoopProviding).self)
        toolManager = kernel.resolveProvider((any ToolManagerProviding).self)
        Self.logger.info(
            "\(Self.t)授权桥接已启动 agentLoop=\(self.agentLoop != nil, privacy: .public) toolManager=\(self.toolManager != nil, privacy: .public)"
        )
    }

    func stop() {
        agentLoop = nil
        toolManager = nil
        Self.logger.info("\(Self.t)授权桥接已停止")
    }

    fileprivate func permissionRequest(for toolCall: ToolCall) -> ToolPermissionRequest? {
        if let content = toolCall.result?.content,
           let request = try? JSONDecoder().decode(
               ToolPermissionRequest.self,
               from: Data(content.utf8)
           ),
           request.kind == "permission" {
            Self.logger.info(
                "\(Self.t)使用工具结果中的授权请求 tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public)"
            )
            return request
        }
        guard let risk = toolManager?.riskLevel(for: toolCall) else {
            Self.logger.warning(
                "\(Self.t)无法判断工具风险，跳过授权界面 tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public)"
            )
            return nil
        }
        guard risk.requiresPermission else {
            Self.logger.debug(
                "\(Self.t)工具风险不要求授权 tool=\(toolCall.name, privacy: .public) risk=\(risk.rawValue, privacy: .public)"
            )
            return nil
        }
        Self.logger.info(
            "\(Self.t)根据风险等级生成授权请求 tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public) risk=\(risk.rawValue, privacy: .public)"
        )
        return ToolPermissionRequest(
            toolCallID: "approval:\(toolCall.id)",
            kind: "permission",
            question: "此操作被判定为\(risk.displayName)，是否允许执行？\n\(toolManager?.displayDescription(for: toolCall) ?? toolCall.name)",
            options: ["允许", "拒绝"],
            mode: "yes_no"
        )
    }

    func resolve(conversationID: UUID, toolCall: ToolCall, answer: String) {
        guard let toolManager else {
            Self.logger.error(
                "\(Self.t)提交授权结果失败：ToolManager 不可用 tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public)"
            )
            return
        }
        let turnID = agentLoop?.currentTurnID(for: conversationID)
        let approved = Self.isApproval(answer)
        Self.logger.info(
            "\(Self.t)提交授权结果 tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public) approved=\(approved, privacy: .public)"
        )
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
public struct ToolApprovalRowRenderer: ToolCallRowRenderer, SuperLog {
    public static let id = "tool-approval-row"
    public static let priority = 120
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.message-renderer",
        category: "ToolApprovalRowRenderer"
    )

    public init() {}

    public func canRender(toolCall: ToolCall) -> Bool {
        let hasNoResult = toolCall.result == nil
        let isPending = toolCall.authorizationState == .pendingAuthorization
        let shouldRender = hasNoResult && isPending
        if shouldRender {
            Self.logger.info(
                "\(Self.t)命中授权界面渲染条件 tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public) authorization=\(toolCall.authorizationState.rawValue, privacy: .public) hasResult=\(toolCall.result != nil, privacy: .public)"
            )
        } else {
            Self.logger.debug(
                "\(Self.t)未命中授权界面渲染条件 tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public) authorization=\(toolCall.authorizationState.rawValue, privacy: .public) hasResult=\(toolCall.result != nil, privacy: .public)"
            )
        }
        return shouldRender
    }

    @MainActor
    public func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        guard let request = ToolApprovalBridge.shared.permissionRequest(for: toolCall) else {
            Self.logger.error(
                "\(Self.t)授权渲染器已命中但无法构造授权请求 tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public)"
            )
            return AnyView(Text("无法解析工具审批请求"))
        }

        Self.logger.info(
            "\(Self.t)显示授权界面 tool=\(toolCall.name, privacy: .public) id=\(toolCall.id, privacy: .public) conversation=\(message.conversationId.uuidString, privacy: .public)"
        )

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

            HStack {
                ForEach(request.options.indices, id: \.self) { index in
                    if index > request.options.startIndex {
                        Spacer(minLength: 0)
                    }

                    let option = request.options[index]
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
