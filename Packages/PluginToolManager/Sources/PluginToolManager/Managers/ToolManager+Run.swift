import Foundation
import KitAgentTool
import KitSuperLog
import os
import ProviderToolManager

private struct ToolInteractionPayload: Codable {
    let toolCallID: String
    let kind: String
    let question: String
    let options: [String]
    let mode: String
}

// MARK: - Tool Execution

extension ToolManager {
    public func execute(_ toolCall: ToolCall, conversationID: UUID, turnID: UUID?) async -> ToolCallResult {
        if let cached = resultCache[toolCall.id] {
            return cached
        }

        if Self.verbose {
            Self.logger.debug("\(Self.t)🚛 execute tool=\(toolCall.name), conversation=\(conversationID.uuidString.prefix(8))")
        }
        eventManager.send(.started(conversationID: conversationID, turnID: turnID, toolCall: toolCall))

        func finish(_ result: ToolCallResult) -> ToolCallResult {
            eventManager.send(.completed(conversationID: conversationID, turnID: turnID, toolCall: toolCall, result: result))
            return result
        }
        guard !deletedConversationIDs.contains(conversationID) else {
            let result = ToolCallResult(content: "Conversation was deleted", isError: true)
            cache(result, for: toolCall.id, conversationID: conversationID)
            return finish(result)
        }

        let startedAt = Date()
        let createdAt = Date()

        let jobs = submit(
            [toolCall],
            policy: .autoExecute,
            conversationID: conversationID,
            turnID: turnID
        )
        guard let job = jobs.first,
              let result = await waitForJobResult(jobID: job.id) else {
            let result = ToolCallResult(content: "Tool execution could not be scheduled.", isError: true)
            cache(result, for: toolCall.id, conversationID: conversationID)
            return finish(result)
        }

        cache(result, for: toolCall.id, conversationID: conversationID)
        let tool = registeredTools[toolCall.name]
        let arguments = try? ToolArgumentCoding.decode(toolCall.arguments)
        logToolCall(
            toolCallID: toolCall.id,
            toolName: tool?.name ?? toolCall.name,
            toolDisplayName: arguments.flatMap { tool?.displayDescription(for: $0) } ?? toolCall.name,
            turnID: turnID,
            conversationID: conversationID,
            createdAt: createdAt,
            startedAt: startedAt,
            completedAt: Date(),
            duration: result.duration ?? Date().timeIntervalSince(startedAt),
            argumentsJSON: arguments.map(ToolArgumentCoding.encode) ?? ToolArgumentCoding.sanitized(toolCall.arguments),
            resultContent: result.content,
            result: result,
            resultIsError: result.isError,
            riskLevel: arguments.flatMap { tool?.permissionRiskLevel(arguments: $0).rawValue } ?? "unknown"
        )
        return finish(result)
    }

    public func executeBatch(_ toolCalls: [ToolCall], policy: ToolExecutionPolicy, conversationID: UUID, turnID: UUID?) async -> [BatchToolResult] {
        if Self.verbose {
            Self.logger.info("\(Self.t)🚛 execute batch count=\(toolCalls.count), conversation=\(conversationID.uuidString.prefix(8)), policy=\(String(describing: policy))")
        }
        var results: [BatchToolResult] = []
        results.reserveCapacity(toolCalls.count)
        batchLoop: for toolCall in toolCalls {
            if Self.verbose {
                Self.logger.info("\(Self.t)🚀 batch tool begin id=\(toolCall.id), name=\(toolCall.name), conversation=\(conversationID.uuidString.prefix(8)), turn=\(turnID?.uuidString.prefix(8) ?? "nil")")
            }
            switch policy {
            case .blockAll:
                results.append(.blocked(reason: "Tool execution was blocked because this conversation is in Chat mode."))
            case .autoExecute:
                results.append(.executed(await execute(toolCall, conversationID: conversationID, turnID: turnID)))
            case .requireApprovalForHighRisk:
                if case .requiresUserApproval = authorizationDecision(
                    for: toolCall,
                    conversationID: conversationID
                ) {
                    let risk = riskLevel(for: toolCall) ?? .high
                    eventManager.send(.authorizationRequired(
                        conversationID: conversationID,
                        turnID: turnID,
                        toolCall: toolCall
                    ))
                    let payload = ToolInteractionPayload(
                        toolCallID: "approval:\(toolCall.id)",
                        kind: "permission",
                        question: "此操作被判定为\(risk.displayName)，是否允许执行？\n\(displayDescription(for: toolCall) ?? toolCall.name)",
                        options: ["允许", "拒绝"],
                        mode: "yes_no"
                    )
                    let content = (try? String(data: JSONEncoder().encode(payload), encoding: .utf8))
                        ?? "Unable to create tool interaction request."
                    results.append(.needsUserResponse(payload: content))
                    // 授权是批次的暂停点；后续调用必须等用户决定后再处理。
                    break batchLoop
                } else {
                    results.append(.executed(await execute(toolCall, conversationID: conversationID, turnID: turnID)))
                }
            }
        }
        if Self.verbose {
            let kinds = results.map { result -> String in
                switch result {
                case .executed: return "executed"
                case .blocked: return "blocked"
                case .needsUserResponse: return "needsUserResponse"
                }
            }
            Self.logger.info("\(Self.t)✅ batch results prepared count=\(results.count), kinds=\(kinds)")
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ batch completed conversation=\(conversationID.uuidString.prefix(8)), results=\(results.count)")
        }
        eventManager.send(.batchCompleted(conversationID: conversationID, turnID: turnID, toolCalls: toolCalls, results: results))
        return results
    }

    public func executeAuthorized(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        var authorizedToolCall = toolCall
        authorizedToolCall.authorizationState = .userApproved
        // 授权界面可能在应用重启后再次出现。若工具已在上一个进程中完成，
        // 直接复用持久化/内存结果，避免再次产生文件修改等副作用。
        if let existingResult = await toolCallResult(for: toolCall.id) {
            eventManager.send(.authorizedCompleted(
                conversationID: conversationID,
                turnID: turnID,
                toolCall: authorizedToolCall,
                result: existingResult
            ))
            return existingResult
        }
        let result = await execute(authorizedToolCall, conversationID: conversationID, turnID: turnID)
        eventManager.send(.authorizedCompleted(
            conversationID: conversationID,
            turnID: turnID,
            toolCall: authorizedToolCall,
            result: result
        ))
        return result
    }

    public func rejectAuthorized(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        var rejectedToolCall = toolCall
        rejectedToolCall.authorizationState = .userRejected
        let result = ToolCallResult(content: "Tool execution was rejected by the user.", isError: true)
        eventManager.send(.authorizedCompleted(
            conversationID: conversationID,
            turnID: turnID,
            toolCall: rejectedToolCall,
            result: result
        ))
        return result
    }

    public func toolCalls(for turnID: UUID) async -> [ToolCallRecord] {
        guard let recordStore else { return [] }
        return await recordStore.fetchRecords(for: turnID)
    }

    public func toolCallResult(for toolCallID: String) async -> ToolCallResult? {
        if let cached = resultCache[toolCallID] { return cached }
        guard let record = await recordStore?.fetchRecord(forToolCallID: toolCallID) else { return nil }
        if let json = record.resultJSON, let data = json.data(using: .utf8), let result = try? JSONDecoder().decode(ToolCallResult.self, from: data) { return result }
        return ToolCallResult(content: record.resultContent, isError: record.resultIsError, duration: record.duration)
    }

    public func deleteToolCalls(for conversationID: UUID) async {
        deletedConversationIDs.insert(conversationID)
        await jobRecordStore?.deleteAll(for: conversationID)
        if let records = await recordStore?.fetchRecords(for: conversationID) {
            for record in records { if let toolCallID = record.toolCallID { resultCache.removeValue(forKey: toolCallID) } }
        }
        resultCacheConversationIDs = resultCacheConversationIDs.filter { $0.value != conversationID }
        resultCache = resultCache.filter { resultCacheConversationIDs[$0.key] != nil }
        await recordStore?.deleteAll(for: conversationID)
    }

    func cache(_ result: ToolCallResult, for toolCallID: String, conversationID: UUID) {
        guard !deletedConversationIDs.contains(conversationID) else { return }
        resultCache[toolCallID] = result
        resultCacheConversationIDs[toolCallID] = conversationID
    }

    func logToolCall(toolCallID: String, toolName: String, toolDisplayName: String, turnID: UUID?, conversationID: UUID, createdAt: Date, startedAt: Date, completedAt: Date?, duration: TimeInterval?, argumentsJSON: String, resultContent: String, result: ToolCallResult, resultIsError: Bool, riskLevel: String) {
        guard let store = recordStore else { return }
        Task {
            await store.record(toolCallID: toolCallID, toolName: toolName, toolDisplayName: toolDisplayName, turnID: turnID, conversationID: conversationID, createdAt: createdAt, startedAt: startedAt, completedAt: completedAt, duration: duration, argumentsJSON: argumentsJSON, resultContent: resultContent, resultJSON: Self.encodeResult(result), resultIsError: resultIsError, riskLevel: riskLevel)
        }
    }

    private static func encodeResult(_ result: ToolCallResult) -> String? {
        guard let data = try? JSONEncoder().encode(result) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
