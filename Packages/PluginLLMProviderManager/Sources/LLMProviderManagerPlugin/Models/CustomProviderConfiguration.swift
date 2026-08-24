import Foundation
import KernelLumi

enum CustomProviderProtocol: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI
    case anthropic
    case responses

    var id: String { rawValue }
    var title: String {
        switch self {
        case .openAI: "OpenAI Chat"
        case .anthropic: "Anthropic Messages"
        case .responses: "OpenAI Responses"
        }
    }
    var defaultPath: String {
        switch self {
        case .openAI: "/v1/chat/completions"
        case .anthropic: "/v1/messages"
        case .responses: "/v1/responses"
        }
    }
}

struct CustomModelConfiguration: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var displayName: String
    var contextWindowSize: Int?
    var supportsVision: Bool
    var supportsTools: Bool

    init(id: String, displayName: String = "", contextWindowSize: Int? = nil, supportsVision: Bool = true, supportsTools: Bool = true) {
        self.id = id
        self.displayName = displayName
        self.contextWindowSize = contextWindowSize
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
    }

    var modelInfo: LumiModelInfo {
        LumiModelInfo(
            id: id,
            displayName: displayName.isEmpty ? nil : displayName,
            contextWindowSize: contextWindowSize,
            capabilities: .init(supportsVision: supportsVision, supportsTools: supportsTools)
        )
    }
}

struct CustomProviderConfiguration: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var protocolType: CustomProviderProtocol
    var baseURL: String
    var models: [CustomModelConfiguration]
    var defaultModel: String

    var apiKeyStorageKey: String { "CustomLLMProvider.ApiKey.\(id)" }

    var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: id,
            displayName: name,
            description: "自定义 \(protocolType.title) 供应商",
            defaultModel: defaultModel.isEmpty ? (models.first?.id ?? "") : defaultModel,
            availableModels: models.map(\.modelInfo),
            websiteURL: URL(string: baseURL) ?? URL(string: "https://example.invalid")!,
            apiFormat: apiFormat,
            apiKeyStorageKey: apiKeyStorageKey
        )
    }

    /// 与 `CustomProviderProtocol` 对应的 API 协议格式
    var apiFormat: LumiLLMAPIFormat {
        switch protocolType {
        case .openAI: .openAI
        case .anthropic: .anthropic
        case .responses: .responses
        }
    }

    func validated() throws -> CustomProviderConfiguration {
        var result = self
        result.id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.id.isEmpty, !result.name.isEmpty else { throw ValidationError.missingName }
        guard URL(string: result.baseURL)?.scheme != nil else { throw ValidationError.invalidURL }
        result.models = models.map { model in
            var copy = model
            copy.id = copy.id.trimmingCharacters(in: .whitespacesAndNewlines)
            return copy
        }.filter { !$0.id.isEmpty }
        guard !result.models.isEmpty else { throw ValidationError.missingModel }
        if !result.models.contains(where: { $0.id == result.defaultModel }) {
            result.defaultModel = result.models[0].id
        }
        return result
    }

    enum ValidationError: LocalizedError {
        case missingName, invalidURL, missingModel
        var errorDescription: String? {
            switch self {
            case .missingName: "请填写供应商名称和唯一 ID"
            case .invalidURL: "请输入有效的 Base URL"
            case .missingModel: "至少添加一个模型 ID"
            }
        }
    }
}
