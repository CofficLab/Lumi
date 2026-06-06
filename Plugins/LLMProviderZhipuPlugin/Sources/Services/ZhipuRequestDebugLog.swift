import AgentToolKit
import Foundation
import HttpKit
import LLMKit
import LumiCoreKit
import os

/// 智谱聊天请求调试日志（Console 过滤 `llm.zhipu.transport` 或 `[ZhipuTransport]`）。
enum ZhipuRequestDebugLog {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.zhipu.transport")

    static func logOutgoingRequest(
        mode: String,
        config: LLMConfig,
        rawMessages: [ChatMessage],
        preparedMessages: [ChatMessage],
        request: URLRequest,
        body: [String: Any],
        tools: [SuperAgentTool]?
    ) {
        let apiKey = ZhipuProvider.getApiKey().trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKeySummary = apiKey.isEmpty
            ? "empty"
            : "\(HTTPClient.maskSensitiveValue(key: "x-api-key", value: apiKey)) (len=\(apiKey.count))"

        let headers = HTTPClient.sanitizeHeaders(request.allHTTPHeaderFields ?? [:])
        let systemPrompt = body["system"] as? String ?? ""
        let conversationMessages = body["messages"] as? [[String: Any]] ?? []
        let bodyTools = body["tools"] as? [[String: Any]] ?? []
        let toolNamesFromBody = bodyTools.compactMap { $0["name"] as? String }
        let toolNamesFromArg = tools?.map(\.name) ?? []

        let bodySizeBytes: Int = {
            guard JSONSerialization.isValidJSONObject(body),
                  let data = try? JSONSerialization.data(withJSONObject: body) else {
                return -1
            }
            return data.count
        }()

        let roleCounts = roleSummary(preparedMessages)
        let bodyKeys = body.keys.sorted().joined(separator: ", ")

        logger.info("""
        [ZhipuTransport] outgoing request
        mode=\(mode, privacy: .public)
        url=\(request.url?.absoluteString ?? "nil", privacy: .public)
        providerId=\(config.providerId, privacy: .public)
        model=\(config.model, privacy: .public)
        apiKey=\(apiKeySummary, privacy: .public)
        headers=\(String(describing: headers), privacy: .public)
        messages raw=\(rawMessages.count, privacy: .public) prepared=\(preparedMessages.count, privacy: .public) conversation=\(conversationMessages.count, privacy: .public)
        roles=\(roleCounts, privacy: .public)
        systemPromptChars=\(systemPrompt.count, privacy: .public)
        configTemperature=\(String(describing: config.temperature), privacy: .public)
        configMaxTokens=\(String(describing: config.maxTokens), privacy: .public)
        bodyKeys=[\(bodyKeys, privacy: .public)]
        bodyMaxTokens=\(String(describing: body["max_tokens"]), privacy: .public)
        bodyStream=\(String(describing: body["stream"]), privacy: .public)
        bodyTemperature=\(String(describing: body["temperature"]), privacy: .public)
        toolsInBody=\(bodyTools.count, privacy: .public)
        toolNamesInBody=\(summarizeNames(toolNamesFromBody), privacy: .public)
        toolNamesArg=\(summarizeNames(toolNamesFromArg), privacy: .public)
        bodySizeBytes=\(bodySizeBytes, privacy: .public)
        """)

        // 同步到 Agent 发送链路日志，确保 Xcode Console 可见（与 🔥 AgentSendPipelineLog 同一管道）
        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[ZhipuTransport] \(mode) model=\(config.model) apiKey=\(apiKeySummary) msgs=\(rawMessages.count)/\(preparedMessages.count)/\(conversationMessages.count) roles={\(roleCounts)} systemChars=\(systemPrompt.count) tools=\(bodyTools.count) bodyBytes=\(bodySizeBytes) url=\(request.url?.absoluteString ?? "nil")")
        }
    }

    static func logHTTPError(statusCode: Int, responseBody: String) {
        let preview = responseBody.count > 500
            ? String(responseBody.prefix(500)) + "…"
            : responseBody
        logger.error("""
        [ZhipuTransport] HTTP error
        status=\(statusCode, privacy: .public)
        body=\(preview, privacy: .public)
        """)
        if AgentSendPipelineLog.enabled {
            AgentSendPipelineLog.logger.info("\(AgentSendPipelineLog.t)[ZhipuTransport] HTTP error status=\(statusCode) body=\(preview)")
        }
    }

    private static func roleSummary(_ messages: [ChatMessage]) -> String {
        var counts: [MessageRole: Int] = [:]
        for message in messages {
            counts[message.role, default: 0] += 1
        }
        let roles: [MessageRole] = [.user, .assistant, .system, .tool, .status, .error, .unknown]
        return roles
            .compactMap { role in
                guard let count = counts[role], count > 0 else { return nil }
                return "\(role.rawValue):\(count)"
            }
            .joined(separator: ", ")
    }

    private static func summarizeNames(_ names: [String], limit: Int = 12) -> String {
        guard !names.isEmpty else { return "[]" }
        if names.count <= limit {
            return "[\(names.joined(separator: ", "))]"
        }
        let head = names.prefix(limit).joined(separator: ", ")
        return "[\(head), …+\(names.count - limit) more]"
    }
}
