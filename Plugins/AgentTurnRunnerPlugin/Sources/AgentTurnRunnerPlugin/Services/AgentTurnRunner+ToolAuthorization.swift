import Foundation
import LumiKernel

// MARK: - Tool Authorization

extension AgentTurnRunner {
    static let toolApprovalSuspensionKind = "toolApproval"

    /// Applies the conversation's automation policy immediately before a tool
    /// is executed. `.chat` denies tools, `.build` prompts for high-risk calls,
    /// and `.autonomous` executes without an approval prompt.
    func executeToolCall(
        _ toolCall: LumiToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> LumiToolResult {
        guard let kernel, let toolManager = kernel.toolManager else {
            return LumiToolResult(content: "Tool manager is unavailable", isError: true)
        }

        let automationLevel = kernel.conversations?.automationLevel(for: conversationID) ?? .build
        switch automationLevel {
        case .chat:
            return LumiToolResult(
                content: "Tool execution was blocked because this conversation is in Chat mode.",
                isError: true
            )
        case .autonomous:
            return await toolManager.execute(toolCall, conversationID: conversationID, turnID: turnID)
        case .build:
            let riskLevel = toolManager.riskLevel(for: toolCall) ?? .high
            let explicitlyRequiresApproval = toolManager.tool(named: toolCall.name)?
                .tags.contains(.requiresApproval) == true
            guard riskLevel.requiresPermission || explicitlyRequiresApproval else {
                return await toolManager.execute(toolCall, conversationID: conversationID, turnID: turnID)
            }
            return makeToolApprovalResult(
                for: toolCall,
                riskLevel: riskLevel,
                conversationID: conversationID
            )
        }
    }

    /// Executes a call after the user has explicitly approved it. This bypasses
    /// only the already-satisfied prompt; the tool manager remains the single
    /// execution entry point.
    func executeApprovedToolCall(
        _ toolCall: LumiToolCall,
        conversationID: UUID
    ) async -> LumiToolResult {
        guard let toolManager = kernel?.toolManager else {
            return LumiToolResult(content: "Tool manager is unavailable", isError: true)
        }
        return await toolManager.execute(
            toolCall,
            conversationID: conversationID,
            turnID: turnIDs[conversationID]
        )
    }

    func isToolApprovalGranted(_ answer: String) -> Bool {
        switch answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "允许", "同意", "是", "allow", "approve", "approved", "yes":
            return true
        default:
            return false
        }
    }

    private func makeToolApprovalResult(
        for toolCall: LumiToolCall,
        riskLevel: LumiCommandRiskLevel,
        conversationID: UUID
    ) -> LumiToolResult {
        let suspensionID = "approval:\(toolCall.id)"
        let operation = toolCall.displayDescription ?? toolCall.name
        let payload = ToolApprovalPayload(
            toolCallId: suspensionID,
            question: "此操作被判定为\(riskLevel.displayName)，是否允许执行？\n\(operation)",
            options: ["允许", "拒绝"],
            mode: "yes_no",
            conversationId: conversationID.uuidString,
            verbosity: "standard"
        )
        let content = (try? String(data: JSONEncoder().encode(payload), encoding: .utf8))
            ?? "Unable to create tool approval request."
        let suspension = AgentTurnSuspension(
            suspensionID: suspensionID,
            conversationID: conversationID,
            toolCallID: toolCall.id,
            kind: Self.toolApprovalSuspensionKind,
            payload: content
        )
        return LumiToolResult(content: content, turnControl: .suspend(suspension))
    }
}

private extension LumiCommandRiskLevel {
    var displayName: String {
        switch self {
        case .safe: "安全"
        case .low: "低风险"
        case .medium: "中风险"
        case .high: "高风险"
        }
    }
}
