import Foundation
import AgentToolKit
import AskUserPlugin
import LumiCoreKit

/// 工具调用执行器
///
/// 负责执行一批工具调用并汇报进度。
/// 包含权限判断、逐个执行、进度汇报、取消处理。
@MainActor
final class ToolCallExecutor: SuperLog {
    nonisolated static let emoji = "🔧"
    nonisolated static let verbose: Bool = false // 链路日志见 AgentSendPipelineLog

    nonisolated static func userRejectedToolResult() -> ToolCallResult {
        ToolCallResult(content: "用户拒绝执行此工具", isError: true)
    }

    nonisolated static func cancelledToolResult(duration: TimeInterval? = nil) -> ToolCallResult {
        ToolCallResult(content: "执行已取消", isError: true, duration: duration)
    }

    nonisolated static func markUnfinishedToolCallsCancelled(
        _ calls: inout [ToolCall],
        startingAt startIndex: Int
    ) {
        guard calls.indices.contains(startIndex) else { return }

        for index in startIndex..<calls.endIndex where calls[index].result == nil {
            calls[index].result = cancelledToolResult()
        }
    }

    nonisolated static func markRejectedToolCallAndCancelFollowing(
        _ calls: inout [ToolCall],
        rejectedAt rejectedIndex: Int
    ) {
        guard calls.indices.contains(rejectedIndex) else { return }

        calls[rejectedIndex].result = userRejectedToolResult()
        markUnfinishedToolCallsCancelled(&calls, startingAt: rejectedIndex + 1)
    }

    private let toolService: ToolService
    private let agentSessionConfig: AppLLMVM
    private let permissionRequestVM: WindowPermissionRequestVM
    private let conversationSendStatusVM: WindowConversationStatusVM
    private let conversationVM: WindowConversationVM
    private let projectVM: WindowProjectVM
    private let recentProjectPathsProvider: @MainActor () -> [String]

    init(
        toolService: ToolService,
        agentSessionConfig: AppLLMVM,
        permissionRequestVM: WindowPermissionRequestVM,
        conversationSendStatusVM: WindowConversationStatusVM,
        conversationVM: WindowConversationVM,
        projectVM: WindowProjectVM,
        recentProjectPathsProvider: @escaping @MainActor () -> [String] = { [] }
    ) {
        self.toolService = toolService
        self.agentSessionConfig = agentSessionConfig
        self.permissionRequestVM = permissionRequestVM
        self.conversationSendStatusVM = conversationSendStatusVM
        self.conversationVM = conversationVM
        self.projectVM = projectVM
        self.recentProjectPathsProvider = recentProjectPathsProvider
    }

    // MARK: - 权限评估

    /// 评估助手消息中所有工具调用的风险等级，并设置授权状态。
    ///
    /// - Returns: 评估后的消息（toolCalls 的 authorizationState 已更新）
    @discardableResult
    func evaluatePermissions(for message: ChatMessage, conversationId: UUID? = nil) -> ChatMessage {
        var message = message
        guard var calls = message.toolCalls else { return message }

        let autoApproveRisk = agentSessionConfig.chatMode.autoApproveRisk
        let allowedDirectories = buildAllowedDirectories()
        let currentProjectPath = projectVM.currentProjectPath.isEmpty ? nil : projectVM.currentProjectPath

        for i in calls.indices {
            let context = ToolExecutionContext(
                conversationId: conversationId ?? message.conversationId,
                toolCallId: calls[i].id,
                toolName: calls[i].name,
                currentProjectPath: currentProjectPath,
                allowedDirectories: allowedDirectories
            )
            let risk = toolService.evaluateRisk(
                toolName: calls[i].name,
                argumentsJSON: calls[i].arguments,
                context: context
            )

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

        let context = ToolExecutionContext(
            conversationId: conversationId,
            toolCallId: firstPending.id,
            toolName: firstPending.name,
            currentProjectPath: projectVM.currentProjectPath.isEmpty ? nil : projectVM.currentProjectPath,
            allowedDirectories: buildAllowedDirectories()
        )
        let risk = toolService.evaluateRisk(
            toolName: firstPending.name,
            argumentsJSON: firstPending.arguments,
            context: context
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

    /// 执行某条助手消息中的全部工具调用，将结果写回 assistant 消息内的 `ToolCall.result`。
    ///
    /// - Returns: 执行结果摘要（是否有用户拒绝、是否有等待用户回答的工具）
    @discardableResult
    func executeAll(assistantMessage: ChatMessage, conversationId: UUID) async -> ToolExecutionSummary {
        guard var updatedCalls = assistantMessage.toolCalls, !updatedCalls.isEmpty else {
            return ToolExecutionSummary()
        }

        let totalCount = updatedCalls.count
        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[\(AgentSendPipelineLog.conv(conversationId))] ⑤ [ToolExecutor] executeAll count=\(totalCount)")
        }
        var hadUserRejection = false
        var hasAwaitingUserResponse = false

        for (index, toolCall) in updatedCalls.enumerated() where toolCall.result == nil {
            if Task.isCancelled {
                conversationSendStatusVM.applyToolProgressEvent(
                    conversationId: conversationId,
                    event: .cancelledAll
                )
                Self.markUnfinishedToolCallsCancelled(&updatedCalls, startingAt: index)
                break
            }

            if toolCall.authorizationState == .userRejected {
                hadUserRejection = true
                Self.markRejectedToolCallAndCancelFollowing(&updatedCalls, rejectedAt: index)
                break
            }

            // 在执行前写入 displayName（由工具自身根据参数生成）
            if updatedCalls[index].displayName == nil {
                updatedCalls[index].displayName = toolService.displayDescription(
                    toolName: toolCall.name,
                    argumentsJSON: toolCall.arguments
                )
            }

            let result = await executeOne(
                toolCall: toolCall,
                step: index + 1,
                total: totalCount,
                conversationId: conversationId
            )
            updatedCalls[index].result = result

            // 检测到等待用户回答，标记并暂停后续工具执行
            if result.awaitingUserResponse {
                hasAwaitingUserResponse = true
                // 将后续未执行的工具标记为取消
                Self.markUnfinishedToolCallsCancelled(&updatedCalls, startingAt: index + 1)
                break
            }
        }

        var updatedAssistant = assistantMessage
        updatedAssistant.toolCalls = updatedCalls
        conversationVM.saveMessage(updatedAssistant, to: conversationId)

        return ToolExecutionSummary(
            hadUserRejection: hadUserRejection,
            hasAwaitingUserResponse: hasAwaitingUserResponse
        )
    }

    // MARK: - 私有

    private func executeOne(
        toolCall: ToolCall,
        step: Int,
        total: Int,
        conversationId: UUID
    ) async -> ToolCallResult {
        let startedAt = Date()
        let initialShellStats = await shellStats(for: toolCall.name)

        // 通过工具实例获取面向用户的操作描述
        let displayName = toolService.displayDescription(
            toolName: toolCall.name,
            argumentsJSON: toolCall.arguments
        )

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
            toolName: toolCall.name,
            currentProjectPath: projectVM.currentProjectPath.isEmpty ? nil : projectVM.currentProjectPath,
            allowedDirectories: buildAllowedDirectories()
        )

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

            let elapsedDuration = Date().timeIntervalSince(startedAt)

            let toolResult: ToolCallResult
            // 检测等待用户回答的标记
            let isAwaitingUser = result.hasPrefix(AskUserTool.pendingPrefix)

            if let decoded = ToolImageResultCodec.decode(result) {
                toolResult = ToolCallResult(
                    content: decoded.content,
                    images: decoded.images,
                    isError: Self.isToolErrorOutput(decoded.content),
                    duration: elapsedDuration,
                    awaitingUserResponse: isAwaitingUser
                )
            } else {
                toolResult = ToolCallResult(
                    content: result,
                    isError: Self.isToolErrorOutput(result),
                    duration: elapsedDuration,
                    awaitingUserResponse: isAwaitingUser
                )
            }

            conversationSendStatusVM.applyToolProgressEvent(
                conversationId: conversationId,
                event: .completed(toolName: toolCall.name, current: step, total: total, elapsedSeconds: Int(elapsedDuration), displayName: displayName)
            )
            return toolResult
        } catch is CancellationError {
            progressTask.cancel()
            let elapsedDuration = Date().timeIntervalSince(startedAt)
            conversationSendStatusVM.applyToolProgressEvent(
                conversationId: conversationId,
                event: .cancelled(toolName: toolCall.name, current: step, total: total, displayName: displayName)
            )
            return Self.cancelledToolResult(duration: elapsedDuration)
        } catch {
            progressTask.cancel()
            let elapsedDuration = Date().timeIntervalSince(startedAt)
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
            return createErrorResult(for: toolCall, error: error, duration: elapsedDuration)
        }
    }

    private func createErrorResult(for toolCall: ToolCall, error: Error, duration: TimeInterval? = nil) -> ToolCallResult {
        let errorContent: String
        if let toolError = error as? ToolExecutionError {
            errorContent = toolError.localizedDescription
        } else {
            errorContent = "Error executing tool: \(error.localizedDescription)"
        }

        return ToolCallResult(content: errorContent, isError: true, duration: duration)
    }

    nonisolated static func isToolErrorOutput(_ output: String) -> Bool {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("Error:") || trimmed.hasPrefix("错误：")
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
                let shellStats = await self.shellStats(for: toolCall.name)
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

    private func shellStats(for toolName: String) async -> ToolProgressShellStats? {
        guard let snapshot = await toolService.progressSnapshot(for: toolName) else { return nil }
        return ToolProgressShellStats(
            totalLines: snapshot.totalLines,
            totalBytes: snapshot.totalBytes,
            latestOutputPreview: snapshot.latestOutputPreview
        )
    }

    // MARK: - Sandbox Helpers

    /// 构建允许的目录列表：当前项目 + 最近项目的规范化路径
    private func buildAllowedDirectories() -> [String] {
        var dirs: [String] = []

        // 当前项目路径
        if !projectVM.currentProjectPath.isEmpty {
            dirs.append(ToolExecutionContext.resolvePath(projectVM.currentProjectPath))
        }

        for path in recentProjectPathsProvider() {
            let resolved = ToolExecutionContext.resolvePath(path)
            if !dirs.contains(resolved) {
                dirs.append(resolved)
            }
        }

        return dirs
    }
}
