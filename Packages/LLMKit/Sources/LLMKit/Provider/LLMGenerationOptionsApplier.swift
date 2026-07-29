import Foundation

/// OpenAI 兼容 API 的生成参数映射。
public enum OpenAICompatibleGenerationOptionsApplier {
    public static func apply(config: LLMConfig, model: String, to body: inout [String: Any]) {
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

        if let reasoningEffort = normalizedReasoningEffort(config.reasoningEffort) {
            body["reasoning_effort"] = reasoningEffort
        }
    }

    private static func normalizedReasoningEffort(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized != "auto", normalized != "automatic" else { return nil }
        guard ["minimal", "low", "medium", "high"].contains(normalized) else { return nil }
        return normalized
    }
}

/// Anthropic 兼容 API 的生成参数映射。
public enum AnthropicCompatibleGenerationOptionsApplier {
    public static func apply(
        config: LLMConfig,
        model: String,
        defaultMaxTokens: Int,
        to body: inout [String: Any]
    ) {
        _ = model
        if let temperature = config.temperature {
            body["temperature"] = temperature
        }

        if let maxTokens = config.maxTokens {
            body["max_tokens"] = maxTokens
        } else if body["max_tokens"] == nil {
            body["max_tokens"] = defaultMaxTokens
        }

        if let budget = thinkingBudgetTokens(for: config.reasoningEffort) {
            body["thinking"] = [
                "type": "enabled",
                "budget_tokens": budget,
            ]
            let currentMaxTokens = body["max_tokens"] as? Int ?? defaultMaxTokens
            body["max_tokens"] = max(currentMaxTokens, budget + 1024)
        }
    }

    private static func thinkingBudgetTokens(for value: String?) -> Int? {
        guard let value else { return nil }
        switch value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "low": return 1024
        case "medium": return 4096
        case "high": return 8192
        default: return nil
        }
    }
}

/// 消息发送前的通用整理（保留 system + 可发送角色）。
public enum LLMMessagePreparer {
    public static func prepare(_ messages: [ChatMessage]) -> [ChatMessage] {
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
