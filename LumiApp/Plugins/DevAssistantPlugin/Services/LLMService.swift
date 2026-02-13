import Combine
import SwiftUI
import Foundation
import OSLog
import MagicKit

/// LLM 服务
///
/// 使用供应商协议处理所有 LLM 请求，支持动态供应商注册。
@MainActor
class LLMService: SuperLog {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose = true

    static let shared = LLMService()

    private let logger = Logger(subsystem: "com.lumi.devassistant", category: "LLM")
    private let registry: ProviderRegistry

    private init() {
        self.registry = ProviderRegistry.shared
        if Self.verbose {
            os_log("\(self.t)LLM 服务已初始化")
        }
    }

    // MARK: - 发送消息

    /// 发送消息到指定的 LLM 供应商
    /// - Parameters:
    ///   - messages: 消息历史
    ///   - config: LLM 配置
    ///   - tools: 可用工具列表
    /// - Returns: AI 助手的响应消息
    func sendMessage(messages: [ChatMessage], config: LLMConfig, tools: [AgentTool]? = nil) async throws -> ChatMessage {
        guard !config.apiKey.isEmpty else {
            os_log(.error, "\(self.t)API Key 为空")
            throw NSError(domain: "LLMService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API Key is missing"])
        }

        // 从注册表获取供应商实例
        guard let provider = registry.createProvider(id: config.providerId) else {
            os_log(.error, "\(self.t)未找到供应商: \(config.providerId)")
            throw NSError(domain: "LLMService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Provider not found: \(config.providerId)"])
        }

        // 构建 URL
        guard let url = URL(string: provider.baseURL) else {
            os_log(.error, "\(self.t)无效的 URL: \(provider.baseURL)")
            throw NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Base URL: \(provider.baseURL)"])
        }

        // 构建请求
        var request = provider.buildRequest(url: url, apiKey: config.apiKey)

        // 构建请求体
        let body: [String: Any]
        do {
            body = try provider.buildRequestBody(
                messages: messages,
                model: config.model,
                tools: tools,
                systemPrompt: "" // 系统提示已包含在 messages 中
            )
        } catch {
            os_log(.error, "\(self.t)构建请求体失败: \(error.localizedDescription)")
            throw error
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if Self.verbose {
            os_log("\(self.t)发送请求到 \(config.providerId): \(config.model)")
        }

        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)

        // 验证响应
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode) else {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            let urlString = request.url?.absoluteString ?? "Unknown URL"
            let bodyString = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "No Body"

            let errorMessage = "API Error (\(config.providerId)): \(errorStr)\nURL: \(urlString)\nBody: \(bodyString)"
            os_log(.error, "\(self.t)\(errorMessage)")

            throw NSError(
                domain: "LLMService",
                code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
        }

        // 解析响应
        let (content, toolCalls) = try provider.parseResponse(data: data)

        if Self.verbose {
            if let toolCalls = toolCalls, !toolCalls.isEmpty {
                os_log("\(self.t)收到响应: \(content.prefix(100))...，包含 \(toolCalls.count) 个工具调用")
            } else {
                os_log("\(self.t)收到响应: \(content.prefix(100))...")
            }
        }

        return ChatMessage(role: .assistant, content: content, toolCalls: toolCalls)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
