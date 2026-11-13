import Foundation

/// Stable identifiers for messages that belong to the visible conversation
/// timeline but are not part of the user's conversational content.
public enum MessageTimelineEvent {
    public static let metadataKey = "lumi.timelineEvent"
    public static let contextCompaction = "context-compaction"
    public static let contextCompactionRenderKind = "context-compaction"
    public static let agentLoopRetry = "agent-loop-retry"
    public static let agentLoopRetryRenderKind = "agent-loop-retry"
    public static let agentLoopRetryAttemptKey = "agentLoopRetryAttempt"
    public static let agentLoopRetryMaxAttemptsKey = "agentLoopRetryMaxAttempts"
    public static let agentLoopRetryReasonKey = "agentLoopRetryReason"
    public static let agentLoopRetryKindKey = "agentLoopRetryKind"
    public static let agentLoopRetryProviderIDKey = "agentLoopRetryProviderID"
    public static let agentLoopRetryModelNameKey = "agentLoopRetryModelName"
    public static let agentLoopRetryHTTPStatusCodeKey = "agentLoopRetryHTTPStatusCode"
    /// 服务端建议的重试等待秒数（来自 `Retry-After` 响应头）。
    public static let agentLoopRetryRetryAfterKey = "agentLoopRetryRetryAfter"
    public static let goalTaskContinuation = "goal-task-continuation"
    public static let goalTaskContinuationRenderKind = "goal-task-continuation"
    /// 用户主动切换模型的结构化时间线事件。
    ///
    /// 该消息把「从哪个供应商/模型切到了哪个供应商/模型」显式呈现给用户，
    /// 只用于界面时间线，不应进入后续 LLM 上下文。
    public static let modelSwitched = "model-switched"
    public static let modelSwitchedRenderKind = "model-switched"
    /// 切换前的供应商 ID。
    public static let modelSwitchedFromProviderIDKey = "modelSwitchedFromProviderID"
    /// 切换前的模型名。
    public static let modelSwitchedFromModelNameKey = "modelSwitchedFromModelName"
    /// 切换后的供应商 ID。
    public static let modelSwitchedToProviderIDKey = "modelSwitchedToProviderID"
    /// 切换后的模型名。
    public static let modelSwitchedToModelNameKey = "modelSwitchedToModelName"
    /// App Store Connect 提交审核的结构化时间线事件。
    ///
    /// 该消息把「即将提交的版本 / Build / 平台 / 状态 / 本地化」显式呈现给用户，
    /// 只用于界面时间线，不应进入后续 LLM 上下文。
    public static let appStoreSubmission = "app-store-submission"
    public static let appStoreSubmissionRenderKind = "app-store-submission"
    /// Finder 插件的卡片时间线事件。
    ///
    /// 插件在工具执行后插入一条带该标记的消息，由插件自己注册的渲染器
    /// 画成可交互卡片。这条消息只是给人看的界面产物，不是一次对话轮次，
    /// 因此不应进入后续 LLM 上下文。
    public static let finder = "finder"
    public static let finderRenderKind = "finder-card"
    /// HTML 画布插件的卡片时间线事件。
    ///
    /// 插件在工具执行后插入一条带该标记的消息，由插件自己注册的渲染器
    /// 画成一张 HTML 界面卡片。这条消息只是给人看的界面产物，不是一次对话轮次，
    /// 因此不应进入后续 LLM 上下文。
    public static let htmlCanvas = "html-canvas"
    public static let htmlCanvasRenderKind = "html-canvas"
    /// 磁盘测速插件的卡片时间线事件。
    ///
    /// 插件在工具执行后插入一条带该标记的消息，由插件自己注册的渲染器
    /// 画成一张测速进度卡片。这条消息只是给人看的界面产物，不是一次对话轮次，
    /// 因此不应进入后续 LLM 上下文。
    public static let diskSpeed = "disk-speed"
    public static let diskSpeedRenderKind = "disk-speed"
    /// 设备信息插件的卡片时间线事件。
    ///
    /// 插件在工具执行后插入一条带该标记的消息，由插件自己注册的渲染器
    /// 画成一张设备状态卡片。这条消息只是给人看的界面产物，不是一次对话轮次，
    /// 因此不应进入后续 LLM 上下文。
    public static let deviceStatus = "device-status"
    public static let deviceStatusRenderKind = "device-status"
    /// 子代理委托插件的卡片时间线事件（#1313 Task 6）。
    ///
    /// 派发委托时插入一条带该标记的消息，由插件自己注册的渲染器画成
    /// 一张进度卡片（工具数、耗时）。这条消息只是给人看的界面产物，
    /// 不是一次对话轮次，因此不应进入后续 LLM 上下文。
    public static let subagentDelegation = "subagent-delegation"
    public static let subagentDelegationRenderKind = "subagent-delegation"
    public static let goalTaskContinuationActionKey = "goalTaskContinuationAction"
    public static let goalTaskContinuationAttemptKey = "goalTaskContinuationAttempt"
    public static let goalTaskContinuationMaxAttemptsKey = "goalTaskContinuationMaxAttempts"
    public static let goalTaskContinuationGoalTitlesKey = "goalTaskContinuationGoalTitles"
    public static let goalTaskContinuationReasonKey = "goalTaskContinuationReason"
    public static let goalTaskContinuationContinuing = "continuing"
    public static let goalTaskContinuationLimitReached = "limit-reached"
    public static let actualContextCompactionKey = "contextCompactionActual"
    public static let actualContextCompactionValue = "true"
    public static let contextCompactionSchemaVersionKey = "contextCompactionSchemaVersion"
    public static let contextCompactionReasonKey = "contextCompactionReason"
    public static let contextCompactionContextWindowTokensKey = "contextCompactionContextWindowTokens"
    public static let contextCompactionEffectiveWindowTokensKey = "contextCompactionEffectiveWindowTokens"
    public static let contextCompactionInputTokenLimitKey = "contextCompactionInputTokenLimit"
    public static let contextCompactionEstimateSourceKey = "contextCompactionEstimateSource"
    public static let contextCompactionOriginalEstimateKey = "contextCompactionOriginalEstimate"
    public static let contextCompactionCompactedEstimateKey = "contextCompactionCompactedEstimate"
    public static let contextCompactionSourceLastMessageIDKey = "contextCompactionSourceLastMessageID"
    /// 产出本次摘要的供应商（轻量任务模型可能与对话主模型不同）。
    public static let contextCompactionSummaryProviderIDKey = "contextCompactionSummaryProviderID"
    /// 产出本次摘要的模型名。
    public static let contextCompactionSummaryModelNameKey = "contextCompactionSummaryModelName"
    /// 摘要调用消耗的 token（输入 + 输出）；缺失表示用量不可用。
    public static let contextCompactionSpentTokensKey = "contextCompactionSpentTokens"
    /// 摘要用量是否为估算口径（"true" / "false"）。
    public static let contextCompactionSpentIsEstimatedKey = "contextCompactionSpentIsEstimated"
    public static let contextCompactionInputTokensKey = "contextCompactionInputTokens"
    public static let contextCompactionOutputTokensKey = "contextCompactionOutputTokens"
    public static let contextCompactionCachedInputTokensKey = "contextCompactionCachedInputTokens"
    public static let contextCompactionCacheWriteTokensKey = "contextCompactionCacheWriteTokens"
    public static let contextCompactionCacheTotalTokensKey = "contextCompactionCacheTotalTokens"

    public enum ContextCompactionReason: String, Sendable, Equatable {
        case hardThreshold = "hard-threshold"
        case emergency = "emergency"
        case contextLimitRetry = "context-limit-retry"
        case legacy = "legacy"
    }

    public static func isContextCompaction(_ message: Message) -> Bool {
        message.renderKind == contextCompactionRenderKind
            || message.metadata[metadataKey] == contextCompaction
    }

    public static func isAgentLoopRetry(_ message: Message) -> Bool {
        message.renderKind == agentLoopRetryRenderKind
            || message.metadata[metadataKey] == agentLoopRetry
    }

    public static func isGoalTaskContinuation(_ message: Message) -> Bool {
        message.renderKind == goalTaskContinuationRenderKind
            || message.metadata[metadataKey] == goalTaskContinuation
    }

    /// 是否属于 App Store Connect 提交审核的结构化时间线事件。
    public static func isAppStoreSubmission(_ message: Message) -> Bool {
        message.renderKind == appStoreSubmissionRenderKind
            || message.metadata[metadataKey] == appStoreSubmission
    }

    /// 是否属于「用户主动切换模型」的结构化时间线事件。
    public static func isModelSwitched(_ message: Message) -> Bool {
        message.renderKind == modelSwitchedRenderKind
            || message.metadata[metadataKey] == modelSwitched
    }

    /// 是否属于 Finder 插件的卡片时间线事件。
    public static func isFinder(_ message: Message) -> Bool {
        message.renderKind == finderRenderKind
            || message.metadata[metadataKey] == finder
    }

    /// 是否属于 HTML 画布插件的卡片时间线事件。
    public static func isHTMLCanvas(_ message: Message) -> Bool {
        message.renderKind == htmlCanvasRenderKind
            || message.metadata[metadataKey] == htmlCanvas
    }

    /// 是否属于磁盘测速插件的卡片时间线事件。
    public static func isDiskSpeed(_ message: Message) -> Bool {
        message.renderKind == diskSpeedRenderKind
            || message.metadata[metadataKey] == diskSpeed
    }

    /// 是否属于设备信息插件的卡片时间线事件。
    public static func isDeviceStatus(_ message: Message) -> Bool {
        message.renderKind == deviceStatusRenderKind
            || message.metadata[metadataKey] == deviceStatus
    }

    /// 是否属于子代理委托插件的卡片时间线事件。
    public static func isSubagentDelegation(_ message: Message) -> Bool {
        message.renderKind == subagentDelegationRenderKind
            || message.metadata[metadataKey] == subagentDelegation
    }

    /// 仅用于界面时间线的消息不应被重新发送给 LLM。
    public static func isTimelineEvent(_ message: Message) -> Bool {
        isContextCompaction(message)
            || isAgentLoopRetry(message)
            || isGoalTaskContinuation(message)
            || isAppStoreSubmission(message)
            || isModelSwitched(message)
            || isFinder(message)
            || isHTMLCanvas(message)
            || isDiskSpeed(message)
            || isDeviceStatus(message)
            || isSubagentDelegation(message)
    }

    /// 只有真正用于压缩上下文的事件才应显示在消息列表中。
    /// 旧版本把后台摘要预热也记录成了压缩事件，因此没有该标记的历史事件继续隐藏。
    public static func isActualContextCompaction(_ message: Message) -> Bool {
        isContextCompaction(message)
            && message.metadata[actualContextCompactionKey] == actualContextCompactionValue
    }

    public static func compactionReason(for message: Message) -> ContextCompactionReason {
        guard let rawValue = message.metadata[contextCompactionReasonKey],
              let reason = ContextCompactionReason(rawValue: rawValue) else {
            return .legacy
        }
        return reason
    }

    public static func integerMetadata(_ key: String, from message: Message) -> Int? {
        guard let value = message.metadata[key] else { return nil }
        return Int(value)
    }

    /// 压缩节省的估算 token（压缩前 − 压缩后）；任一端缺失时为 `nil`。
    public static func compactionSavedTokens(for message: Message) -> Int? {
        guard let original = integerMetadata(contextCompactionOriginalEstimateKey, from: message),
              let compacted = integerMetadata(contextCompactionCompactedEstimateKey, from: message) else {
            return nil
        }
        return original - compacted
    }

    /// 摘要调用消耗的 token；未记录时为 `nil`（不可用）。
    public static func compactionSpentTokens(for message: Message) -> Int? {
        integerMetadata(contextCompactionSpentTokensKey, from: message)
    }

    /// 摘要用量是否为估算口径。
    public static func compactionSpentIsEstimated(for message: Message) -> Bool {
        message.metadata[contextCompactionSpentIsEstimatedKey] == "true"
    }

    /// 压缩净收益 = 节省（估算）− 摘要消耗；任一端缺失时为 `nil`。
    public static func compactionNetTokens(for message: Message) -> Int? {
        guard let saved = compactionSavedTokens(for: message),
              let spent = compactionSpentTokens(for: message) else {
            return nil
        }
        return saved - spent
    }
}
