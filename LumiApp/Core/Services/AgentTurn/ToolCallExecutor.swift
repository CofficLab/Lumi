import Foundation
import ToolKit

/// 工具调用执行器
///
/// 负责执行一批工具调用并汇报进度。
/// 包含权限判断、逐个执行、进度汇报、取消处理。
@MainActor
final class ToolCallExecutor: SuperLog {
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose: Bool = false

    private let toolService: ToolService
    private let agentSessionConfig: AppLLMVM
    private let permissionRequestVM: WindowPermissionRequestVM
    private let conversationSendStatusVM: WindowConversationStatusVM
    private let conversationVM: WindowConversationVM

    init(
        toolService: ToolService,
        agentSessionConfig: AppLLMVM,
        permissionRequestVM: WindowPermissionRequestVM,
        conversationSendStatusVM: WindowConversationStatusVM,
        conversationVM: WindowConversationVM
    ) {
        self.toolService = toolService
        self.agentSessionConfig = agentSessionConfig
        self.permissionRequestVM = permissionRequestVM
        self.conversationSendStatusVM = conversationSendStatusVM
        self.conversationVM = conversationVM
    }

    // MARK: - 权限评估

    /// 评估助手消息中所有工具调用的风险等级，并设置授权状态。
    ///
    /// - Returns: 评估后的消息（toolCalls 的 authorizationState 已更新）
    @discardableResult
    func evaluatePermissions(for message: ChatMessage) -> ChatMessage {
        var message = message
        guard var calls = message.toolCalls else { return message }

        let autoApproveRisk = agentSessionConfig.chatMode.autoApproveRisk

        for i in calls.indices {
            let risk = toolService.evaluateRisk(toolName: calls[i].name, argumentsJSON: calls[i].arguments)

            if Self.verbose {
                AppLogger.core.info("\(Self.t)🔨 工具：\(calls[i].name)，风险：\(risk.displayName)")
            }

            if !risk.requiresPermission {
                calls[i].authorizationState = .noRisk
            } else if autoApproveRisk {
                calls[i].authorizationState = .autoApproved
            } else {
                calls[i].authorizationState = .pendingAuthorization
            }
        }
        message.toolCalls = calls
        return message
    }

    /// 若存在待授权的工具调用，弹出权限请求 UI 并返回 true（调用方应暂停循环）。
    func presentPermissionIfNeeded(assistantMessage: ChatMessage, conversationId: UUID) async -> Bool {
        guard let calls = assistantMessage.toolCalls,
              let firstPending = calls.first(where: { $0.authorizationState.needsAuthorizationPrompt }) else {
            return false
        }

        let risk = toolService.evaluateRisk(toolName: firstPending.name, argumentsJSON: firstPending.arguments)
        let request = PermissionRequest(
            toolName: firstPending.name,
            argumentsString: firstPending.arguments,
            toolCallID: firstPending.id,
            riskLevel: risk
        )

        permissionRequestVM.setPendingPermissionRequest(request)
        permissionRequestVM.setPendingToolPermissionSession(
            PendingToolPermissionSession(
                conversationId: conversationId,
                assistantMessageId: assistantMessage.id
            )
        )
        conversationSendStatusVM.setStatus(
            conversationId: conversationId,
            content: "等待工具授权：\(firstPending.name)…"
        )
        return true
    }

    // MARK: - 执行工具

    /// 执行某条助手消息中的全部工具调用，将每条结果以 `role: .tool` 消息落库。
    ///
    /// - Returns: 是否存在用户拒绝的工具调用
    @discardableResult
    func executeAll(assistantMessage: ChatMessage, conversationId: UUID) async -> Bool {
        guard let toolCalls = assistantMessage.toolCalls, !toolCalls.isEmpty else { return false }

        let totalCount = toolCalls.count
        var hadUserRejection = false

        for (index, toolCall) in toolCalls.enumerated() {
            if Task.isCancelled {
                conversationSendStatusVM.applyToolProgressEvent(
                    conversationId: conversationId,
                    event: .cancelledAll
                )
                break
            }

            if toolCall.authorizationState == .userRejected {
                hadUserRejection = true
                let resultMsg = ChatMessage(
                    role: .tool,
                    conversationId: conversationId,
                    content: "用户拒绝执行此工具",
                    toolCallID: toolCall.id
                )
                conversationVM.saveMessage(resultMsg, to: conversationId)
                continue
            }

            let resultMsg = await executeOne(
                toolCall: toolCall,
                step: index + 1,
                total: totalCount,
                conversationId: conversationId
            )
            conversationVM.saveMessage(resultMsg, to: conversationId)
        }

        return hadUserRejection
    }

    // MARK: - 私有

    private func extractDisplayName(from argumentsJSON: String) -> String? {
        guard let dict = ToolService.parseToolArgumentsDict(from: argumentsJSON),
              let name = dict["display_name"] as? String,
              !name.isEmpty else {
            return nil
        }
        return name
    }

    private func executeOne(
        toolCall: ToolCall,
        step: Int,
        total: Int,
        conversationId: UUID
    ) async -> ChatMessage {
        let startedAt = Date()
        let initialShellStats = await Self.shellStats(for: toolCall.name)
        let displayName = extractDisplayName(from: toolCall.arguments)

        conversationSendStatusVM.applyToolProgressEvent(
            conversationId: conversationId,
            event: .running(
                toolName: toolCall.name,
                current: step,
                total: total,
                elapsedSeconds: 0,
                shellStats: initialShellStats,
                displayName: displayName
            )
        )

        let progressTask = launchProgressReporter(
            toolCall: toolCall,
            displayName: displayName,
            step: step,
            total: total,
            startedAt: startedAt,
            conversationId: conversationId
        )
        let toolContext = ToolExecutionContext(
            conversationId: conversationId,
            toolCallId: toolCall.id,
            toolName: toolCall.name
        )

        let resultMsg: ChatMessage
        do {
            let result = try await withTaskCancellationHandler {
                try toolContext.checkCancellation()
                return try await toolService.executeTool(toolCall, context: toolContext)
            } onCancel: {
                progressTask.cancel()
                toolContext.cancel()
            }
            try toolContext.checkCancellation()
            progressTask.cancel()
            if let decoded = ToolImageResultCodec.decode(result) {
                resultMsg = ChatMessage(
                    role: .tool,
                    conversationId: conversationId,
                    content: decoded.content,
                    toolCallID: toolCall.id,
                    images: decoded.images
                )
            } else {
                resultMsg = ChatMessage(
                    role: .tool,
                    conversationId: conversationId,
                    content: result,
                    toolCallID: toolCall.id
                )
            }
            conversationSendStatusVM.applyToolProgressEvent(
                conversationId: conversationId,
                event: .completed(toolName: toolCall.name, current: step, total: total, displayName: displayName)
            )
        } catch is CancellationError {
            progressTask.cancel()
            conversationSendStatusVM.applyToolProgressEvent(
                conversationId: conversationId,
                event: .cancelled(toolName: toolCall.name, current: step, total: total, displayName: displayName)
            )
            return ChatMessage(
                role: .tool,
                conversationId: conversationId,
                content: "执行已取消",
                toolCallID: toolCall.id
            )
        } catch {
            progressTask.cancel()
            resultMsg = createErrorMessage(for: toolCall, error: error, conversationId: conversationId)
            conversationSendStatusVM.applyToolProgressEvent(
                conversationId: conversationId,
                event: .failed(
                    toolName: toolCall.name,
                    current: step,
                    total: total,
                    errorSummary: Self.errorSummary(from: error),
                    displayName: displayName
                )
            )
        }

        return resultMsg
    }

    private func createErrorMessage(for toolCall: ToolCall, error: Error, conversationId: UUID) -> ChatMessage {
        let errorContent: String
        if let toolError = error as? ToolExecutionError {
            errorContent = toolError.localizedDescription
        } else {
            errorContent = "Error executing tool: \(error.localizedDescription)"
        }

        return ChatMessage(
            role: .tool,
            conversationId: conversationId,
            content: errorContent,
            toolCallID: toolCall.id
        )
    }

    private func launchProgressReporter(
        toolCall: ToolCall,
        displayName: String?,
        step: Int,
        total: Int,
        startedAt: Date,
        conversationId: UUID
    ) -> Task<Void, Never> {
        let statusVM = conversationSendStatusVM
        return Task { [weak statusVM] in
            while !Task.isCancelled {
                let elapsed = Int(Date().timeIntervalSince(startedAt))
                let shellStats = await Self.shellStats(for: toolCall.name)
                await MainActor.run {
                    statusVM?.applyToolProgressEvent(
                        conversationId: conversationId,
                        event: .running(
                            toolName: toolCall.name,
                            current: step,
                            total: total,
                            elapsedSeconds: elapsed,
                            shellStats: shellStats,
                            displayName: displayName
                        )
                    )
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private static func errorSummary(from error: Error) -> String {
        error.localizedDescription
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "未知错误"
    }

    private static func shellStats(for toolName: String) async -> ToolProgressShellStats? {
        guard toolName == "run_command",
              let snapshot = await ShellService.shared.progressSnapshot() else {
            return nil
        }
        return ToolProgressShellStats(
            totalLines: snapshot.totalLines,
            totalBytes: snapshot.totalBytes,
            latestOutputPreview: snapshot.latestOutputPreview
        )
    }
}
