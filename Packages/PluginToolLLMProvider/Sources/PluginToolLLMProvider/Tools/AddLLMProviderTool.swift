import Foundation
import KitAgentTool
import KitLLM
import LumiLoggingKit
import os
import ProviderLLMManager

/// 「添加 LLM 供应商」工具：让 LLM 把一个新供应商整理成**提案**交给用户确认。
///
/// ## 工具不做什么
///
/// 本工具**不写盘、不注册、不碰 Keychain**。它只做三件事：
/// 1. 解析并规范化 LLM 给出的供应商信息；
/// 2. 校验端点地址（`ProviderEndpointPolicy`）与供应商名称；
/// 3. 返回一段人类可读正文 + 末尾 JSON 代码块（提案载荷）。
///
/// 模型列表**不**在这里强制要求：LLM 往往不知道精确的模型 id，
/// 空列表的提案照样成立，由用户在卡片里补齐；卡片保存时才按
/// `UserDefinedCloudProviderConfiguration.validated()` 的规则把关。
///
/// ## 副作用发生在哪里
///
/// 消息里会出现一张卡片（`LLMProviderRowRenderer` 渲染）。用户在卡片上
/// 确认后，才真正调用 `UserDefinedCloudProviderStore.upsert` 落库并注册。
///
/// ## 为什么不让 LLM 直接写 API Key
///
/// API Key 一旦进入对话就会进入对话记录，并随下一次请求发回给模型端点。
/// 因此本工具的入参里**没有** API Key 字段：密钥只由卡片直接写入 Keychain，
/// 全程不经过模型。
public struct AddLLMProviderTool: SuperAgentTool, SuperLog, @unchecked Sendable {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.tool-llm-provider",
        category: "AddLLMProviderTool"
    )

    /// Agent 调用的工具名。
    public static let toolName = "add_llm_provider"

    public let name: String = Self.toolName

    public init() {}

    // MARK: - SuperAgentTool

    public func description(for language: LanguagePreference) -> String {
        """
        Prepare a proposal for adding a new LLM provider (a model service the user wants to \
        connect), and let the user confirm it in the chat.

        Use this when the user asks to add, connect or register a new LLM provider, gateway or \
        self-hosted model service that is not already available in Lumi.

        The tool does NOT save anything by itself. It only prepares a proposal card: the user \
        reviews the endpoint and models, types the API key into the card, and confirms. Tell the \
        user that a card is waiting for their confirmation, and do not claim the provider is \
        already added.

        Never ask the user to paste an API key into the chat. The card collects the key directly \
        and writes it to the keychain, so the key never passes through the model.

        Notes:
        - `baseURL` must be the API root, for example "https://api.example.com/v1".
        - `apiFormat` defaults to "openAI"; use "anthropic" for Anthropic-compatible endpoints.
        - `models` accepts a list of {id, displayName, contextWindowSize, supportsVision, \
        supportsTools}; provide it whenever you know the model ids, otherwise the user fills it in.
        - At most one call per turn.
        """
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "displayName": [
                    "type": "string",
                    "description": "Human readable provider name, e.g. 'Acme Gateway'.",
                ],
                "baseURL": [
                    "type": "string",
                    "description": "API root URL of the provider, e.g. 'https://api.example.com/v1'. Must be https unless it points to localhost.",
                ],
                "apiFormat": [
                    "type": "string",
                    "enum": LLMProviderAPIFormat.allCases.map(\.rawValue),
                    "description": "Wire protocol of the endpoint. Defaults to 'openAI'.",
                ],
                "defaultModel": [
                    "type": "string",
                    "description": "Model id used by default. Falls back to the first model when omitted.",
                ],
                "models": [
                    "type": "array",
                    "description": "Models offered by the provider.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "id": ["type": "string"],
                            "displayName": ["type": "string"],
                            "contextWindowSize": ["type": "integer"],
                            "supportsVision": ["type": "boolean"],
                            "supportsTools": ["type": "boolean"],
                        ],
                        "required": ["id"],
                    ],
                ],
                "websiteURL": [
                    "type": "string",
                    "description": "Optional provider homepage shown in the provider list.",
                ],
                "description": [
                    "type": "string",
                    "description": "Optional short note describing this provider.",
                ],
            ],
            "required": ["displayName", "baseURL"],
        ]
    }

    /// 提案阶段不产生任何副作用，风险定为中档：
    /// 不需要用户审批，但也不应被自动执行模式无声地放行成「已生效」。
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let name = Self.stringArgument("displayName", in: arguments)
        guard let name, !name.isEmpty else {
            return pluginLocalization.string("Add LLM Provider")
        }
        return "\(pluginLocalization.string("Add LLM Provider")): \(name)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let displayName = Self.stringArgument("displayName", in: arguments)
        let baseURL = Self.stringArgument("baseURL", in: arguments)

        guard let displayName, !displayName.isEmpty else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Missing 'displayName' argument"
            )
        }
        guard let baseURL, !baseURL.isEmpty else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Missing 'baseURL' argument"
            )
        }

        // 端点安全策略：远端必须 https，私网 / 链路本地一律拒绝。
        do {
            _ = try ProviderEndpointPolicy.validate(baseURL: baseURL)
        } catch let error as ProviderEndpointPolicyError {
            Self.logger.error("\(Self.t)rejected provider endpoint: \(error.localizedDescription, privacy: .public)")
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: error.localizedDescription
            )
        }

        let apiFormat = Self.apiFormatArgument(in: arguments)
        let models = Self.modelsArgument(in: arguments)
        let defaultModel = Self.stringArgument("defaultModel", in: arguments)
        let websiteURL = Self.stringArgument("websiteURL", in: arguments)
        let providerDescription = Self.stringArgument("description", in: arguments)

        let proposal = LLMProviderProposal(
            id: Self.proposedIdentifier(displayName: displayName),
            displayName: displayName,
            providerDescription: providerDescription ?? "",
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            apiFormat: apiFormat,
            defaultModel: defaultModel ?? models.first?.id ?? "",
            models: models,
            websiteURLString: websiteURL
        )

        Self.logger.info("\(Self.t)prepared provider proposal name=\(displayName, privacy: .public) format=\(apiFormat.rawValue, privacy: .public)")
        return Self.resultText(for: proposal)
    }

    // MARK: - Arguments

    /// 读取字符串参数；空白视为缺省。
    static func stringArgument(_ key: String, in arguments: [String: ToolArgument]) -> String? {
        guard let raw = arguments[key]?.value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 读取协议格式参数；无法识别时退化为 OpenAI 兼容。
    static func apiFormatArgument(in arguments: [String: ToolArgument]) -> LLMProviderAPIFormat {
        guard let raw = stringArgument("apiFormat", in: arguments),
              let format = LLMProviderAPIFormat(rawValue: raw.lowercased()) else {
            return .openAI
        }
        return format
    }

    /// 读取模型列表参数。
    ///
    /// 逐项容错：结构不对的条目直接跳过，不让单个畸形模型毁掉整份提案。
    static func modelsArgument(in arguments: [String: ToolArgument]) -> [UserDefinedCloudModel] {
        guard let raw = arguments["models"]?.value as? [Any] else { return [] }
        var models: [UserDefinedCloudModel] = []
        for element in raw {
            guard let dictionary = element as? [String: Any] else { continue }
            guard let id = stringValue(dictionary["id"]), !id.isEmpty else { continue }
            models.append(
                UserDefinedCloudModel(
                    id: id,
                    displayName: stringValue(dictionary["displayName"]),
                    contextWindowSize: integerValue(dictionary["contextWindowSize"]),
                    supportsVision: booleanValue(dictionary["supportsVision"]) ?? false,
                    supportsTools: booleanValue(dictionary["supportsTools"]) ?? true
                )
            )
        }
        return models
    }

    /// JSON 值转字符串。
    static func stringValue(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// JSON 值转整数（兼容 `NSNumber` 与 `Double`）。
    static func integerValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let double = value as? Double, double.rounded() == double { return Int(double) }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }

    /// JSON 值转布尔。
    static func booleanValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        return nil
    }

    /// 由展示名推导供应商标识。
    ///
    /// 统一加 `custom-` 前缀，避免与内置供应商 id（如 `openai`）撞车——
    /// 同 id 注册会直接覆盖内置实现。
    static func proposedIdentifier(displayName: String) -> String {
        let slug = displayName
            .lowercased()
            .map { character -> Character in
                character.isLetter || character.isNumber ? character : "-"
            }
            .reduce(into: "") { accumulator, character in
                if character == "-", accumulator.hasSuffix("-") { return }
                accumulator.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let normalized = slug.isEmpty ? "provider" : slug
        return "custom-\(normalized)"
    }

    // MARK: - Result

    /// 构造工具返回文本：人类可读正文 + 末尾 JSON 代码块。
    ///
    /// 正文供 LLM 直接理解；JSON 块供 `LLMProviderRowRenderer` 解码成卡片。
    static func resultText(for proposal: LLMProviderProposal) -> String {
        let modelList = proposal.models.isEmpty
            ? "-"
            : proposal.models.map(\.id).joined(separator: ", ")
        return """
        ## LLM Provider Proposal Prepared 📝

        A proposal for **\(proposal.displayName)** is waiting for the user's confirmation in this chat.

        - **Endpoint**: \(proposal.baseURL)
        - **Protocol**: \(proposal.apiFormat.rawValue)
        - **Models**: \(modelList)

        Nothing has been saved yet. The user still has to review the details, type the API key into
        the card and confirm it. Tell the user that the card is waiting, and do not use this
        provider until they confirm.

        \(ProviderProposalPayload.encode(proposal))
        """
    }
}
