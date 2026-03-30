import Foundation

// MARK: - 内置错误消息占位键与工厂

extension ChatMessage {
    // MARK: 占位键

    /// API Key 缺失错误键
    static var apiKeyMissingSystemContentKey: String { "__LUMI_API_KEY_MISSING__" }
    /// LLM 配置相关错误键
    static var llmModelEmptyContentKey: String { "__LUMI_LLM_MODEL_EMPTY__" }
    static var llmProviderIdEmptyContentKey: String { "__LUMI_LLM_PROVIDER_ID_EMPTY__" }
    static var llmTemperatureInvalidContentKey: String { "__LUMI_LLM_TEMPERATURE_INVALID__" }
    static var llmMaxTokensInvalidContentKey: String { "__LUMI_LLM_MAX_TOKENS_INVALID__" }
    static var llmProviderNotFoundContentKey: String { "__LUMI_LLM_PROVIDER_NOT_FOUND__" }
    static var llmInvalidBaseURLContentKey: String { "__LUMI_LLM_INVALID_BASE_URL__" }
    /// 本地模型加载失败错误键
    static var loadingLocalModelFailedSystemContentKey: String { "__LUMI_LOADING_LOCAL_MODEL_FAILED__" }
    /// API 请求失败错误键
    static var apiRequestFailedErrorKey: String { "__LUMI_API_REQUEST_FAILED__" }
    /// 网络连接错误键
    static var networkConnectionErrorKey: String { "__LUMI_NETWORK_CONNECTION_ERROR__" }
    /// 解析错误键
    static var parsingErrorKey: String { "__LUMI_PARSING_ERROR__" }
    /// 认证错误键
    static var authenticationErrorKey: String { "__LUMI_AUTHENTICATION_ERROR__" }
    /// 配额超限错误键
    static var quotaExceededErrorKey: String { "__LUMI_QUOTA_EXCEEDED__" }
    /// 模型不可用错误键
    static var modelNotAvailableErrorKey: String { "__LUMI_MODEL_NOT_AVAILABLE__" }

    // MARK: 工厂

    /// API Key 缺失错误消息
    static func apiKeyMissingMessage(conversationId: UUID) -> ChatMessage {
        ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: Self.apiKeyMissingSystemContentKey,
            isError: true
        )
    }

    /// LLM 模型为空错误消息
    static func llmModelEmptyMessage(conversationId: UUID) -> ChatMessage {
        ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: Self.llmModelEmptyContentKey,
            isError: true
        )
    }

    /// LLM 供应商 ID 为空错误消息
    static func llmProviderIdEmptyMessage(conversationId: UUID) -> ChatMessage {
        ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: Self.llmProviderIdEmptyContentKey,
            isError: true
        )
    }

    /// LLM 温度参数无效错误消息
    static func llmTemperatureInvalidMessage(temperature: Double, conversationId: UUID) -> ChatMessage {
        ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: Self.llmTemperatureInvalidContentKey,
            isError: true,
            temperature: temperature
        )
    }

    /// LLM 最大 token 无效错误消息
    static func llmMaxTokensInvalidMessage(maxTokens: Int, conversationId: UUID) -> ChatMessage {
        ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: Self.llmMaxTokensInvalidContentKey,
            isError: true,
            maxTokens: maxTokens
        )
    }

    /// LLM 供应商未找到错误消息
    static func llmProviderNotFoundMessage(providerId: String, conversationId: UUID) -> ChatMessage {
        ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: Self.llmProviderNotFoundContentKey,
            isError: true,
            providerId: providerId
        )
    }

    /// LLM Base URL 无效错误消息
    static func llmInvalidBaseURLMessage(baseURL: String, conversationId: UUID) -> ChatMessage {
        ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: Self.llmInvalidBaseURLMessageContent(baseURL: baseURL),
            isError: true
        )
    }

    /// 操作已取消错误消息
    static func cancelledMessage(conversationId: UUID) -> ChatMessage {
        ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: String(localized: "操作已取消。"),
            isError: true
        )
    }

    /// LLM 配置错误相关辅助方法
    static func llmInvalidBaseURLMessageContent(baseURL: String) -> String {
        llmInvalidBaseURLContentKey + "\n" + baseURL
    }

    static func llmInvalidBaseURLPayload(fromContent content: String) -> String? {
        guard content.hasPrefix(llmInvalidBaseURLContentKey + "\n") else { return nil }
        let rest = content.dropFirst(llmInvalidBaseURLContentKey.count + 1)
        let s = String(rest).trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    /// 本地模型加载失败错误消息
    static func loadingLocalModelFailedMessage(
        languagePreference: LanguagePreference,
        conversationId: UUID,
        providerId: String? = nil,
        modelName: String? = nil
    ) -> ChatMessage {
        ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: Self.loadingLocalModelFailedSystemContentKey,
            providerId: providerId,
            modelName: modelName
        )
    }

    /// 系统因达到最大执行深度而终止本轮对话时，用于向用户解释原因的错误消息
    static func maxDepthToolLimitMessage(languagePreference: LanguagePreference, currentDepth: Int, maxDepth: Int, conversationId: UUID) -> ChatMessage {
        let content: String
        switch languagePreference {
        case .chinese:
            content = "由于系统限制，本轮对话已达到最大执行深度（\(currentDepth)/\(maxDepth)），后续的工具调用请求已被忽略。请调整问题或缩小任务范围后再试。"
        case .english:
            content = "Due to system safety limits, this turn has reached the maximum execution depth (\(currentDepth)/\(maxDepth)). Additional tool calls have been ignored and the conversation turn has been terminated. Please refine your question or narrow the task scope and try again."
        }
        return ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: content,
            isError: true
        )
    }

    /// 检测到重复工具调用循环时，用于向用户解释原因的错误消息
    static func repeatedToolLoopMessage(
        languagePreference: LanguagePreference,
        tool: ToolCall,
        repeatedCount: Int,
        windowCount: Int,
        conversationId: UUID
    ) -> ChatMessage {
        // 尝试对参数做 JSON pretty-print，便于用户排查
        func formatArgs(_ raw: String) -> String {
            guard !raw.isEmpty,
                  raw != "{}",
                  let data = raw.data(using: .utf8),
                  let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
                return raw
            }
            if let prettyData = try? JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [.prettyPrinted, .sortedKeys]
            ), let pretty = String(data: prettyData, encoding: .utf8) {
                return pretty
            }
            return raw
        }

        let prettyArgs = formatArgs(tool.arguments)

        let content: String
        switch languagePreference {
        case .chinese:
            content = """
            检测到工具 **\(tool.name)** 被多次以相同/高度相似的参数重复调用，疑似进入工具调用循环，本轮对话已被系统自动中止。

            - 重复次数（连续计数）：\(repeatedCount)
            - 重复次数（最近窗口内）：\(windowCount)
            - 调用参数示例：
            ```json
            \(prettyArgs)
            ```

            建议你：
            - 检查提示词中是否要求模型"不断重试同一个工具"
            - 为工具调用增加明确的停止条件或上限
            - 必要时缩小任务范围，改为多轮分步执行
            """
        case .english:
            content = """
            The tool **\(tool.name)** has been repeatedly invoked with the same or highly similar arguments, indicating a possible tool invocation loop. This conversation turn has been automatically terminated for safety.

            - Repeated count (consecutive): \(repeatedCount)
            - Repeated count (within recent window): \(windowCount)
            - Example arguments:
            ```json
            \(prettyArgs)
            ```

            Recommended actions:
            - Check if your prompt tells the model to \"keep retrying\" the same tool
            - Add clear stopping conditions or limits around the tool usage
            - Consider splitting the task into smaller, sequential steps
            """
        }

        return ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: content,
            isError: true
        )
    }

    /// 请求失败（如超时、网络错误）时，用于在对话中展示的错误消息
    static func requestFailedMessage(languagePreference: LanguagePreference, error: Error, conversationId: UUID) -> ChatMessage {
        let isTimeout = Self.isTimeoutError(error)
        let content: String
        if isTimeout {
            switch languagePreference {
            case .chinese:
                content = "请求超时，本轮已终止。请检查网络或稍后重试。"
            case .english:
                content = "Request timed out; this turn has been terminated. Please check your network or try again later."
            }
        } else {
            switch languagePreference {
            case .chinese:
                content = "请求失败，本轮已终止：\(error.localizedDescription)。请检查网络或稍后重试。"
            case .english:
                content = "Request failed; this turn has been terminated: \(error.localizedDescription). Please check your network or try again later."
            }
        }
        return ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: content,
            isError: true
        )
    }

    /// API 请求失败错误消息
    static func apiRequestFailedMessage(
        languagePreference: LanguagePreference,
        error: Error,
        conversationId: UUID
    ) -> ChatMessage {
        let isTimeout = Self.isTimeoutError(error)
        let content: String
        if isTimeout {
            switch languagePreference {
            case .chinese:
                content = "请求超时，本轮已终止。请检查网络或稍后重试。"
            case .english:
                content = "Request timed out; this turn has been terminated. Please check your network or try again later."
            }
        } else {
            switch languagePreference {
            case .chinese:
                content = "API 请求失败：\(error.localizedDescription)"
            case .english:
                content = "API request failed: \(error.localizedDescription)"
            }
        }
        return ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: content,
            isError: true
        )
    }

    /// 网络连接错误消息
    static func networkConnectionErrorMessage(
        languagePreference: LanguagePreference,
        conversationId: UUID
    ) -> ChatMessage {
        let content: String
        switch languagePreference {
        case .chinese:
            content = "网络连接失败。请检查网络设置并重试。"
        case .english:
            content = "Network connection failed. Please check your network settings and try again."
        }
        return ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: content,
            isError: true
        )
    }

    /// 解析错误消息
    static func parsingErrorMessage(
        languagePreference: LanguagePreference,
        details: String? = nil,
        conversationId: UUID
    ) -> ChatMessage {
        let content: String
        switch languagePreference {
        case .chinese:
            if let details = details {
                content = "解析响应失败：\(details)"
            } else {
                content = "解析响应失败。请稍后重试。"
            }
        case .english:
            if let details = details {
                content = "Failed to parse response: \(details)"
            } else {
                content = "Failed to parse response. Please try again later."
            }
        }
        return ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: content,
            isError: true
        )
    }

    /// 认证错误消息
    static func authenticationErrorMessage(
        languagePreference: LanguagePreference,
        conversationId: UUID
    ) -> ChatMessage {
        let content: String
        switch languagePreference {
        case .chinese:
            content = "认证失败。请检查 API Key 是否正确。"
        case .english:
            content = "Authentication failed. Please check if your API Key is correct."
        }
        return ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: content,
            isError: true
        )
    }

    /// 配额超限错误消息
    static func quotaExceededErrorMessage(
        languagePreference: LanguagePreference,
        conversationId: UUID
    ) -> ChatMessage {
        let content: String
        switch languagePreference {
        case .chinese:
            content = "已达到使用配额上限。请检查账户状态或升级计划。"
        case .english:
            content = "Usage quota exceeded. Please check your account status or upgrade your plan."
        }
        return ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: content,
            isError: true
        )
    }

    /// 模型不可用错误消息
    static func modelNotAvailableErrorMessage(
        languagePreference: LanguagePreference,
        modelName: String? = nil,
        conversationId: UUID
    ) -> ChatMessage {
        let content: String
        switch languagePreference {
        case .chinese:
            if let modelName = modelName {
                content = "模型 \(modelName) 当前不可用。请稍后重试或选择其他模型。"
            } else {
                content = "模型当前不可用。请稍后重试或选择其他模型。"
            }
        case .english:
            if let modelName = modelName {
                content = "Model \(modelName) is currently unavailable. Please try again later or select a different model."
            } else {
                content = "Model is currently unavailable. Please try again later or select a different model."
            }
        }
        return ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: content,
            isError: true
        )
    }
}
