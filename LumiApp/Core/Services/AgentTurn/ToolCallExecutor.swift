import Foundation
import MagicKit

/// 工具调用执行器
///
/// 负责执行一批工具调用并汇报进度。
/// 包含权限判断、逐个执行、进度汇报、取消处理。
@MainActor
final class ToolCallExecutor: SuperLog {
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose = false

    private let toolExecutionService: ToolExecutionService
    private let toolService: ToolService
    private let projectVM: ProjectVM
    private let permissionRequestVM: PermissionRequestVM
    private let conversationSendStatusVM: ConversationStatusVM
    private let conversationVM: ConversationVM

    init(
        toolExecutionService: ToolExecutionService,
        toolService: ToolService,
        projectVM: ProjectVM,
        permissionRequestVM: PermissionRequestVM,
        conversationSendStatusVM: ConversationStatusVM,
        conversationVM: ConversationVM
    ) {
        self.toolExecutionService = toolExecutionService
        self.toolService = toolService
        self.projectVM = projectVM
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

        for i in calls.indices {
            let risk = evaluateRiskSync(toolName: calls[i].name, arguments: calls[i].arguments)

            if Self.verbose {
                AppLogger.core.info("\(Self.t)🔨 工具：\(calls[i].name)，风险：\(risk.displayName)")
            }

            if !risk.requiresPermission {
                calls[i].authorizationState = .noRisk
            } else if projectVM.autoApproveRisk {
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

        let risk = await toolExecutionService.evaluateRisk(
            toolName: firstPending.name,
            arguments: firstPending.arguments
        )
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
                // 跳过被拒绝的工具，但仍记录一条结果
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

    private func executeOne(
        toolCall: ToolCall,
        step: Int,
        total: Int,
        conversationId: UUID
    ) async -> ChatMessage {
        let startedAt = Date()
        let initialShellStats = await Self.shellStats(for: toolCall.name)

        conversationSendStatusVM.applyToolProgressEvent(
            conversationId: conversationId,
            event: .running(
                toolName: toolCall.name,
                current: step,
                total: total,
                elapsedSeconds: 0,
                shellStats: initialShellStats
            )
        )

        let progressTask = launchProgressReporter(
            toolCall: toolCall,
            step: step,
            total: total,
            startedAt: startedAt,
            conversationId: conversationId
        )

        let resultMsg: ChatMessage
        do {
            let result = try await withTaskCancellationHandler {
                try await toolExecutionService.executeTool(toolCall)
            } onCancel: {
                progressTask.cancel()
            }
            progressTask.cancel()
            resultMsg = ChatMessage(
                role: .tool,
                conversationId: conversationId,
                content: result,
                toolCallID: toolCall.id
            )
            conversationSendStatusVM.applyToolProgressEvent(
                conversationId: conversationId,
                event: .completed(toolName: toolCall.name, current: step, total: total)
            )
        } catch is CancellationError {
            progressTask.cancel()
            conversationSendStatusVM.applyToolProgressEvent(
                conversationId: conversationId,
                event: .cancelled(toolName: toolCall.name, current: step, total: total)
            )
            return ChatMessage(
                role: .tool,
                conversationId: conversationId,
                content: "执行已取消",
                toolCallID: toolCall.id
            )
        } catch {
            progressTask.cancel()
            resultMsg = toolExecutionService.createErrorMessage(for: toolCall, error: error, conversationId: conversationId)
            conversationSendStatusVM.applyToolProgressEvent(
                conversationId: conversationId,
                event: .failed(
                    toolName: toolCall.name,
                    current: step,
                    total: total,
                    errorSummary: Self.errorSummary(from: error)
                )
            )
        }

        return resultMsg
    }

    private func launchProgressReporter(
        toolCall: ToolCall,
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
                            shellStats: shellStats
                        )
                    )
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    /// 同步风险评估（用于权限评估阶段，已有 MainActor 保证）
    private func evaluateRiskSync(toolName: String, arguments: String) -> CommandRiskLevel {
        if let declared = toolService.declaredRiskLevel(toolName: toolName, arguments: Self.parseArgsDict(from: arguments) ?? [:]) {
            return declared
        }
        return .high
    }

    private static func parseArgsDict(from arguments: String) -> [String: Any]? {
        let trimmed = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        if let dict = json as? [String: Any] { return dict }
        if let str = json as? String,
           let innerData = str.data(using: .utf8),
           let inner = try? JSONSerialization.jsonObject(with: innerData) as? [String: Any] {
            return inner
        }
        return nil
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
