import Foundation
import Combine
import OSLog

actor LLMService {
    static let shared = LLMService()
    private let logger = Logger(subsystem: "com.lumi.devassistant", category: "LLM")
    
    func sendMessage(messages: [ChatMessage], config: LLMConfig) async throws -> String {
        guard !config.apiKey.isEmpty else {
            throw NSError(domain: "LLMService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API Key is missing"])
        }
        
        switch config.provider {
        case .anthropic:
            return try await sendToAnthropic(messages: messages, apiKey: config.apiKey, model: config.model)
        case .openai, .deepseek:
            return try await sendToOpenAICompatible(messages: messages, config: config)
        }
    }
    
    private func sendToOpenAICompatible(messages: [ChatMessage], config: LLMConfig) async throws -> String {
        guard let urlString = config.baseURL, let url = URL(string: urlString) else {
            throw NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Base URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert ChatMessage to OpenAI format
        // System prompt is just another message with role "system"
        let conversationMessages = messages.map { msg -> [String: String] in
            return [
                "role": msg.role.rawValue,
                "content": msg.content
            ]
        }
        
        let body: [String: Any] = [
            "model": config.model,
            "messages": conversationMessages,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            os_log(.error, "OpenAI/DeepSeek API Error: %s", errorStr)
            throw NSError(domain: "LLMService", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorStr)"])
        }
        
        // Parse OpenAI response
        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return result.choices.first?.message.content ?? ""
    }
    
    private func sendToAnthropic(messages: [ChatMessage], apiKey: String, model: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert ChatMessage to Anthropic format
        // System message is separate in Anthropic API
        let systemMessage = messages.first(where: { $0.role == .system })?.content ?? ""
        let conversationMessages = messages.filter { $0.role != .system }.map { msg -> [String: String] in
            return [
                "role": msg.role.rawValue,
                "content": msg.content
            ]
        }
        
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemMessage,
            "messages": conversationMessages
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            os_log(.error, "Anthropic API Error: %s", errorStr)
            throw NSError(domain: "LLMService", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorStr)"])
        }
        
        // Parse response
        // Structure: { "content": [ { "text": "..." } ] }
        struct AnthropicResponse: Decodable {
            struct Content: Decodable {
                let text: String
            }
            let content: [Content]
        }
        
        let result = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return result.content.first?.text ?? ""
    }
}
