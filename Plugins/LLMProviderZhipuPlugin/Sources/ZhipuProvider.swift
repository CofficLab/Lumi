import Foundation
import HttpKit
import LLMKit
import LumiCoreKit

public final class ZhipuProvider: LumiLLMProvider, @unchecked Sendable {
    public static let shortName = "ZhiPu"
    public static let apiKeyHelpURL: String? = "https://open.bigmodel.cn/usercenter/apikeys"
    public static let apiKeyStorageKey = "DevAssistant_ApiKey_Zhipu"

    public static let info = LumiLLMProviderInfo(
        id: "zhipu",
        displayName: String(localized: "智谱", bundle: .module),
        description: String(localized: "Zhipu AI GLM", bundle: .module),
        defaultModel: "glm-4.7",
        availableModels: [
            "glm-5.1",
            "glm-5-turbo",
            "glm-5",
            "glm-4.7",
            "glm-4.6",
            "glm-4.5",
            "glm-4.5-air",
        ]
    )

    private let apiService: LLMAPIService
    private let baseURL = "https://open.bigmodel.cn/api/anthropic/v1/messages"

    public init(apiService: LLMAPIService = LLMAPIService()) {
        self.apiService = apiService
    }

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        let conversationID = request.messages.first?.conversationID ?? UUID()

        guard let apiKey = Self.getApiKeyIfConfigured() else {
            return Self.errorMessage(
                conversationID: conversationID,
                renderKind: ZhipuRenderKind.apiKeyMissing,
                rawDetail: "Zhipu API Key is not configured."
            )
        }

        guard let url = URL(string: baseURL) else {
            throw LLMServiceError.invalidBaseURL(baseURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = Self.requestBody(messages: request.messages, model: request.model, tools: request.tools)

        do {
            let data = try await apiService.sendChatRequest(request: urlRequest, body: body)
            let response = try Self.parseResponse(data: data)
            return LumiChatMessage(
                conversationID: conversationID,
                role: .assistant,
                content: response.content,
                providerID: Self.info.id,
                modelName: request.model,
                toolCalls: response.toolCalls
            )
        } catch let error as HTTPClientError {
            return Self.errorMessage(
                conversationID: conversationID,
                renderKind: Self.renderKind(for: error),
                rawDetail: error.localizedDescription
            )
        } catch let error as LLMServiceError {
            return Self.errorMessage(
                conversationID: conversationID,
                renderKind: Self.renderKind(for: error),
                rawDetail: error.localizedDescription
            )
        }
    }

    public static func getApiKey() -> String {
        UserDefaults.standard.string(forKey: apiKeyStorageKey) ?? ""
    }

    public static func setApiKey(_ apiKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: apiKeyStorageKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: apiKeyStorageKey)
        }
    }

    private static func getApiKeyIfConfigured() -> String? {
        let storedKey = getApiKey().trimmingCharacters(in: .whitespacesAndNewlines)
        if !storedKey.isEmpty {
            return storedKey
        }

        let environmentKey = ProcessInfo.processInfo.environment["ZHIPU_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return environmentKey?.isEmpty == false ? environmentKey : nil
    }

    private static func requestBody(
        messages: [LumiChatMessage],
        model: String,
        tools: [any LumiAgentTool]
    ) -> [String: Any] {
        let system = messages
            .filter { $0.role == .system }
            .map(\.content)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let conversationMessages = messages
            .filter { $0.role == .user || $0.role == .assistant || $0.role == .tool }
            .map { message -> [String: Any] in
                switch message.role {
                case .assistant:
                    var contentBlocks: [[String: Any]] = []
                    if !message.content.isEmpty {
                        contentBlocks.append(["type": "text", "text": message.content])
                    }

                    for toolCall in message.toolCalls ?? [] {
                        contentBlocks.append([
                            "type": "tool_use",
                            "id": toolCall.id,
                            "name": toolCall.name,
                            "input": argumentsDictionary(from: toolCall.arguments),
                        ])
                    }

                    return [
                        "role": "assistant",
                        "content": contentBlocks.isEmpty ? message.content : contentBlocks,
                    ]

                case .tool:
                    return [
                        "role": "user",
                        "content": [
                            [
                                "type": "tool_result",
                                "tool_use_id": message.toolCallID ?? "",
                                "content": message.content,
                            ],
                        ],
                    ]

                default:
                    return [
                        "role": "user",
                        "content": message.content,
                    ]
                }
            }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": system,
            "messages": conversationMessages,
        ]

        if !tools.isEmpty {
            body["tools"] = tools.map { tool in
                [
                    "name": tool.name,
                    "description": tool.toolDescription,
                    "input_schema": tool.inputSchema.anyValue,
                ]
            }
        }

        return body
    }

    private static func parseResponse(data: Data) throws -> (content: String, toolCalls: [LumiToolCall]?) {
        let result = try JSONDecoder().decode(ZhipuResponse.self, from: data)
        var textParts: [String] = []
        var toolCalls: [LumiToolCall] = []

        for item in result.content {
            if item.type == "text", let text = item.text {
                textParts.append(text)
            } else if item.type == "tool_use",
                      let id = item.id,
                      let name = item.name {
                toolCalls.append(
                    LumiToolCall(
                        id: id,
                        name: name,
                        arguments: jsonString(from: item.input ?? [:])
                    )
                )
            }
        }

        let content = textParts.joined()
        if content.isEmpty && toolCalls.isEmpty {
            throw LLMServiceError.requestFailed("Zhipu response is empty")
        }

        return (content, toolCalls.isEmpty ? nil : toolCalls)
    }

    private static func argumentsDictionary(from json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }

        return object
    }

    private static func jsonString(from dictionary: [String: ZhipuAnyDecodable]) -> String {
        let object = dictionary.reduce(into: [String: Any]()) { result, item in
            result[item.key] = item.value.value
        }

        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return json
    }

    private static func errorMessage(
        conversationID: UUID,
        renderKind: String,
        rawDetail: String?
    ) -> LumiChatMessage {
        LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: info.id,
            isError: true,
            rawErrorDetail: rawDetail,
            renderKind: renderKind
        )
    }

    private static func renderKind(for error: HTTPClientError) -> String {
        switch error {
        case let .httpError(statusCode, _):
            ZhipuRenderKind.http(statusCode)
        default:
            ZhipuRenderKind.requestFailed
        }
    }

    private static func renderKind(for error: LLMServiceError) -> String {
        switch error {
        case .apiKeyEmpty:
            ZhipuRenderKind.apiKeyMissing
        case let .requestFailed(_, statusCode):
            statusCode.map(ZhipuRenderKind.http) ?? ZhipuRenderKind.requestFailed
        default:
            ZhipuRenderKind.requestFailed
        }
    }
}

private struct ZhipuResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
        let id: String?
        let name: String?
        let input: [String: ZhipuAnyDecodable]?
    }
}

private struct ZhipuAnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([ZhipuAnyDecodable].self) {
            value = array.map(\.value)
        } else if let object = try? container.decode([String: ZhipuAnyDecodable].self) {
            value = object.reduce(into: [String: Any]()) { result, item in
                result[item.key] = item.value.value
            }
        } else {
            value = NSNull()
        }
    }
}
