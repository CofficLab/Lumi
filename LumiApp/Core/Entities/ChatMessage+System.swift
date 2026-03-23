import Foundation

// MARK: - 内置系统消息占位键与工厂

extension ChatMessage {
    // MARK: 占位键

    static var apiKeyMissingSystemContentKey: String { "__LUMI_API_KEY_MISSING__" }
    static var llmModelEmptyContentKey: String { "__LUMI_LLM_MODEL_EMPTY__" }
    static var llmProviderIdEmptyContentKey: String { "__LUMI_LLM_PROVIDER_ID_EMPTY__" }
    static var llmTemperatureInvalidContentKey: String { "__LUMI_LLM_TEMPERATURE_INVALID__" }
    static var llmMaxTokensInvalidContentKey: String { "__LUMI_LLM_MAX_TOKENS_INVALID__" }
    static var llmProviderNotFoundContentKey: String { "__LUMI_LLM_PROVIDER_NOT_FOUND__" }
    static var llmInvalidBaseURLContentKey: String { "__LUMI_LLM_INVALID_BASE_URL__" }
    static var loadingLocalModelSystemContentKey: String { "__LUMI_LOADING_LOCAL_MODEL__" }
    static var loadingLocalModelDoneSystemContentKey: String { "__LUMI_LOADING_LOCAL_MODEL_DONE__" }
    static var loadingLocalModelFailedSystemContentKey: String { "__LUMI_LOADING_LOCAL_MODEL_FAILED__" }
    static var turnCompletedSystemContentKey: String { "__LUMI_TURN_COMPLETED__" }

    // MARK: 工厂

    /// 系统因达到最大执行深度而终止本轮对话时，用于向用户解释原因的系统消息。
    static func maxDepthToolLimitMessage(languagePreference: LanguagePreference, currentDepth: Int, maxDepth: Int) -> ChatMessage {
        let content: String
        switch languagePreference {
        case .chinese:
            content = "由于系统限制，本轮对话已达到最大执行深度（\(currentDepth)/\(maxDepth)），后续的工具调用请求已被忽略。请调整问题或缩小任务范围后再试。"
        case .english:
            content = "Due to system safety limits, this turn has reached the maximum execution depth (\(currentDepth)/\(maxDepth)). Additional tool calls have been ignored and the conversation turn has been terminated. Please refine your question or narrow the task scope and try again."
        }
        return ChatMessage(
            role: .system,
            content: content,
            isError: true
        )
    }

    static func makeAbortMessage(toolCallID: String?) -> ChatMessage {
        ChatMessage(
            role: .tool,
            content: "[Tool execution aborted by safety guard]",
            toolCallID: toolCallID
        )
    }

    /// 达到最大深度时的最后一步提醒（作为一条 user 消息追加，用于提示模型不再调用工具、直接给出最终回答）。
    static func maxDepthFinalStepReminderMessage() -> ChatMessage {
        ChatMessage(
            role: .user,
            content: """
            <system-reminder>
            You have reached the final execution step. Do not call any tools anymore.
            Provide your best final answer using the information already collected.
            If critical information is missing, explicitly state what is missing and ask one concise follow-up question.
            </system-reminder>
            """
        )
    }

    /// 请求失败（如超时、网络错误）时，用于在对话中展示的助手错误消息。
    static func requestFailedMessage(languagePreference: LanguagePreference, error: Error) -> ChatMessage {
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
            role: .assistant,
            content: content,
            isError: true
        )
    }

    static func apiKeyMissingSystemMessage(languagePreference: LanguagePreference) -> ChatMessage {
        ChatMessage(
            role: .system,
            content: Self.apiKeyMissingSystemContentKey,
            isError: true
        )
    }

    static func llmInvalidBaseURLMessageContent(baseURL: String) -> String {
        llmInvalidBaseURLContentKey + "\n" + baseURL
    }

    static func llmInvalidBaseURLPayload(fromContent content: String) -> String? {
        guard content.hasPrefix(llmInvalidBaseURLContentKey + "\n") else { return nil }
        let rest = content.dropFirst(llmInvalidBaseURLContentKey.count + 1)
        let s = String(rest).trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    static func loadingLocalModelSystemMessage(
        languagePreference: LanguagePreference,
        providerId: String? = nil,
        modelName: String? = nil
    ) -> ChatMessage {
        ChatMessage(
            role: .system,
            content: Self.loadingLocalModelSystemContentKey,
            providerId: providerId,
            modelName: modelName
        )
    }

    static func turnCompletedSystemMessage(languagePreference: LanguagePreference) -> ChatMessage {
        ChatMessage(
            role: .status,
            content: Self.turnCompletedSystemContentKey
        )
    }

    /// 检测到重复工具调用循环时，用于向用户解释原因的助手消息。
    static func repeatedToolLoopMessage(
        languagePreference: LanguagePreference,
        tool: ToolCall,
        repeatedCount: Int,
        windowCount: Int
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
            - 检查提示词中是否要求模型“不断重试同一个工具”
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
            role: .assistant,
            content: content,
            isError: true
        )
    }
}
