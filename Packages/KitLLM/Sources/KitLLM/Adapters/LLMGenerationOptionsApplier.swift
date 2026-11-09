import Foundation

/// OpenAI 兼容 API 的生成参数映射。
public enum OpenAICompatibleGenerationOptionsApplier {
    /// 所有 OpenAI 兼容网关都接受的基础档位。
    private static let baseReasoningEfforts: Set<String> = ["minimal", "low", "medium", "high"]

    /// 不支持 `reasoning_effort` 的模型族前缀。
    ///
    /// OpenAI Chat Completions 收到未支持的档位会直接返回 400（不可重试），
    /// 因此这些模型必须整条参数省略。只拦截已知的非推理模型族；未知模型
    /// （中转站自定义模型等）保持原有透传行为，避免误伤可用的第三方模型。
    private static let nonReasoningModelPrefixes = ["gpt-4", "gpt-3.5", "chatgpt-4o"]

    static func supportsReasoningEffort(model: String) -> Bool {
        let normalized = model.lowercased()
        return !nonReasoningModelPrefixes.contains { normalized.hasPrefix($0) }
    }

    public static func apply(
        config: LLMConfig,
        model: String,
        additionalReasoningEfforts: [String] = [],
        to body: inout [String: Any]
    ) {
        if let temperature = config.temperature {
            body["temperature"] = temperature
        }

        if let maxTokens = config.maxTokens {
            if model.hasPrefix("o") || model.contains("gpt-5") {
                body["max_completion_tokens"] = maxTokens
            } else {
                body["max_tokens"] = maxTokens
            }
        }

        if supportsReasoningEffort(model: model),
           let reasoningEffort = normalizedReasoningEffort(
               config.reasoningEffort,
               additionalReasoningEfforts: additionalReasoningEfforts
           ) {
            body["reasoning_effort"] = reasoningEffort
        }
    }

    /// 把请求档位归一化为可发送的 `reasoning_effort`。
    ///
    /// - Parameters:
    ///   - value: 用户选择的档位原始字符串。
    ///   - additionalReasoningEfforts: 供应商额外支持的档位（见
    ///     `OpenAICompatibleProviderConfiguration.additionalReasoningEfforts`）。
    ///   - Returns: 归一化后的档位；该档位不被接受时返回 `nil`（不下发该参数）。
    static func normalizedReasoningEffort(
        _ value: String?,
        additionalReasoningEfforts: [String] = []
    ) -> String? {
        guard let value else { return nil }
        let normalized = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized != "auto", normalized != "automatic" else { return nil }
        guard baseReasoningEfforts.contains(normalized)
                || additionalReasoningEfforts.contains(normalized) else { return nil }
        return normalized
    }
}

/// Anthropic 兼容 API 的生成参数映射。
public enum AnthropicCompatibleGenerationOptionsApplier {
    /// 不支持 extended thinking 的 Claude 模型族。
    ///
    /// Anthropic 端点收到这些模型上的 `thinking` 会直接返回 400，因此必须整条
    /// 省略。只拦截已知不支持的模型；非 Claude 模型（DeepSeek、Kimi、自定义
    /// 中转等同样走 Anthropic 格式）保持原有透传行为。
    private static let nonThinkingModelFragments = [
        "claude-3-5-",
        "claude-3-0-",
        "claude-3-opus",
        "claude-3-sonnet",
        "claude-3-haiku",
    ]

    static func supportsExtendedThinking(model: String) -> Bool {
        let normalized = model.lowercased()
        return !nonThinkingModelFragments.contains { normalized.contains($0) }
    }

    /// 单次输出上限只有 4096 的 Claude 3 模型。
    ///
    /// 默认配置给到 8192，超过这些模型的能力会直接被端点以 400 拒绝，因此最终
    /// 下发的 `max_tokens` 必须限幅。其余模型保持配置值，不做统一降低。
    private static let maxOutputTokenCaps: [(fragment: String, cap: Int)] = [
        ("claude-3-opus", 4096),
        ("claude-3-sonnet", 4096),
        ("claude-3-haiku", 4096),
    ]

    static func maxOutputTokens(for model: String) -> Int? {
        let normalized = model.lowercased()
        return maxOutputTokenCaps.first { normalized.contains($0.fragment) }?.cap
    }

    public static func apply(
        config: LLMConfig,
        model: String,
        defaultMaxTokens: Int,
        to body: inout [String: Any]
    ) {
        if let temperature = config.temperature {
            body["temperature"] = temperature
        }

        if let maxTokens = config.maxTokens {
            body["max_tokens"] = maxTokens
        } else if body["max_tokens"] == nil {
            body["max_tokens"] = defaultMaxTokens
        }

        if supportsExtendedThinking(model: model),
           let budget = thinkingBudgetTokens(for: config.reasoningEffort) {
            body["thinking"] = [
                "type": "enabled",
                "budget_tokens": budget,
            ]
            let currentMaxTokens = body["max_tokens"] as? Int ?? defaultMaxTokens
            body["max_tokens"] = max(currentMaxTokens, budget + 1024)
        }

        if let cap = maxOutputTokens(for: model),
           let currentMaxTokens = body["max_tokens"] as? Int,
           currentMaxTokens > cap {
            body["max_tokens"] = cap
        }
    }

    private static func thinkingBudgetTokens(for value: String?) -> Int? {
        guard let value else { return nil }
        switch value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "low": return 1024
        case "medium": return 4096
        case "high": return 8192
        case "xhigh": return 16384
        case "max": return 32768
        default: return nil
        }
    }
}

/// 消息发送前的通用整理（保留 system + 可发送角色）。
public enum LLMMessagePreparer {
    public static func prepare(_ messages: [LLMMessage]) -> [LLMMessage] {
        messages.filter { message in
            switch message.role {
            case .system, .user, .assistant, .tool:
                return true
            case .status, .error, .unknown:
                return false
            }
        }
    }
}
