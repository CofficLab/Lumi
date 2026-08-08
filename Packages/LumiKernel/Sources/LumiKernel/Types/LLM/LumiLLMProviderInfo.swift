import Foundation

/// LLM 模型可用性检测结果
public enum LumiModelAvailabilityResult: Sendable, Equatable {
    case available
    case unavailable(LumiLLMFailureDetail)
}

/// 模型对"思考 / 推理强度"能力的支持级别。
///
/// 不同的 LLM 提供方对推理强度的档位定义并不统一：
/// - 有些模型完全不支持思考（如纯文本生成模型）。
/// - 有些模型支持 3 档（low / medium / high），典型如 OpenAI GPT-5 / o-series。
/// - 有些模型支持 4 档（low / high / xhigh / max），典型如 Anthropic Claude、DeepSeek V4、Qwen3。
/// - 有些模型只有「开 / 关」开关，没有档位（如 MiniMax-M3：可关闭；M2.x：始终开启）。
///   这种情形下 `reasoningEffort` 不适用，UI 应展示为开关或直接隐藏下拉。
///
/// 用枚举显式建模可用的档位数，避免消费端假设"开启思考 = 显示 4 档按钮"。
public enum LumiThinkingSupport: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// 不支持思考 / 推理强度可调
    case unsupported
    /// 支持 3 档推理强度：low / medium / high
    case threeLevel
    /// 支持 4 档推理强度：low / high / xhigh / max
    case fourLevel
    /// 只有「开 / 关」开关，没有档位（例如 MiniMax-M3）。
    /// 此模式下 `LumiReasoningEffort.available(for: .toggle) == []`，
    /// UI 不应展示推理档位下拉，而应展示开关或保持当前服务端默认行为。
    case toggle

    /// 是否启用思考（即至少有一档可选或可开关）
    public var isEnabled: Bool {
        self != .unsupported
    }

    /// 是否存在多个推理档位（true → 需要 `LumiReasoningEffort` 下拉；
    /// false → 单一开关或隐藏）。
    public var hasMultipleLevels: Bool {
        switch self {
        case .threeLevel, .fourLevel: true
        case .unsupported, .toggle: false
        }
    }
}

/// 模型能力声明
public struct LumiModelCapabilities: Sendable, Equatable, Hashable {
    public let supportsVision: Bool
    public let supportsTools: Bool
    public let supportsTTS: Bool
    public let thinkingSupport: LumiThinkingSupport

    public init(
        supportsVision: Bool,
        supportsTools: Bool,
        supportsTTS: Bool = false,
        thinkingSupport: LumiThinkingSupport = .unsupported
    ) {
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.supportsTTS = supportsTTS
        self.thinkingSupport = thinkingSupport
    }
}

/// 单个 LLM 模型的完整配置信息
///
/// 将模型 ID、显示名称、上下文窗口大小、能力声明集中到一个结构体中，
/// 避免在 provider 定义中维护多个平行字典。
public struct LumiModelInfo: Sendable, Equatable, Identifiable, Hashable {
    /// 模型 ID（即发送给 API 的 model 字段值）
    public let id: String

    /// 人类可读的显示名称（nil 则消费端应使用 id 展示）
    public let displayName: String?

    /// 上下文窗口大小（token 数），nil 表示未指定
    public let contextWindowSize: Int?

    /// 模型能力声明，nil 表示未声明
    public let capabilities: LumiModelCapabilities?

    /// 模型参数量（例如 "7B"、"27B"、"1T"），nil 表示未指定
    public let parameterSize: String?

    public init(
        id: String,
        displayName: String? = nil,
        contextWindowSize: Int? = nil,
        capabilities: LumiModelCapabilities? = nil,
        parameterSize: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.contextWindowSize = contextWindowSize
        self.capabilities = capabilities
        self.parameterSize = parameterSize
    }
}

public struct LumiLLMProviderInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let defaultModel: String
    public let availableModels: [LumiModelInfo]
    public let isLocal: Bool
    public let websiteURL: URL
    internal let apiKeyStorageKey: String?

    public var _apiKeyStorageKey: String? { apiKeyStorageKey }

    /// 根据模型 ID 快速查找模型配置
    public func modelInfo(for id: String) -> LumiModelInfo? {
        availableModels.first(where: { $0.id == id })
    }

    /// 模型 ID 列表（便捷属性，供只需 ID 的消费端使用）
    public var modelIDs: [String] {
        availableModels.map(\.id)
    }

    public init(
        id: String,
        displayName: String,
        description: String = "",
        defaultModel: String,
        availableModels: [LumiModelInfo],
        isLocal: Bool = false,
        websiteURL: URL,
        apiKeyStorageKey: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.defaultModel = defaultModel
        self.availableModels = availableModels
        self.isLocal = isLocal
        self.websiteURL = websiteURL
        if isLocal {
            self.apiKeyStorageKey = nil
        } else {
            self.apiKeyStorageKey = apiKeyStorageKey ?? "DevAssistant_ApiKey_\(id)"
        }
    }
}
