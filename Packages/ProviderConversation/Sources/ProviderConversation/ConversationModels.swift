import Foundation

// MARK: - Conversation Types
//
// 复刻自旧版内核 KernelLumi 的 Types/Conversation/LumiConversationTypes.swift、
// Types/Chat/LumiResponseVerbosity.swift、Types/LLM/LLMRequest.swift（LumiReasoningEffort）。
// 类型名保持与旧版一致（Lumi* 前缀），便于旧插件与消费方代码平滑迁移；
// 新版 Provider 包自包含这些模型，不依赖 KernelLumi。

/// 回复语言。
public enum LumiConversationLanguage: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    case chinese
    case english

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case .chinese: "zh"
        case .english: "en"
        }
    }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "zh", "chinese", "cn": self = .chinese
        case "en", "english": self = .english
        default: return nil
        }
    }

    public var shortCode: String {
        switch self { case .chinese: "中"; case .english: "EN" }
    }

    public var displayName: String {
        switch self { case .chinese: "中文"; case .english: "English" }
    }

    public var iconName: String {
        "character.book.closed"
    }
}

/// 自动化等级（对话模式）：决定 Agent 能否执行工具、是否需要确认。
public enum LumiAutomationLevel: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    case chat
    case build
    case autonomous

    public var id: String { rawValue }

    public var rawValue: String {
        switch self { case .chat: "a1"; case .build: "a2"; case .autonomous: "a3" }
    }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "a1", "chat": self = .chat
        case "a2", "build": self = .build
        case "a3", "autonomous": self = .autonomous
        default: return nil
        }
    }

    public var levelCode: String { rawValue.uppercased() }

    public var displayName: String {
        switch self { case .chat: "对话"; case .build: "构建"; case .autonomous: "自主" }
    }

    public var iconName: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right"
        case .build: "hammer.fill"
        case .autonomous: "bolt.shield.fill"
        }
    }

    public var description: String {
        switch self {
        case .chat: "只进行对话，不执行任何工具"
        case .build: "可以执行工具，高风险需要确认"
        case .autonomous: "可以自主执行工具，持续推进任务"
        }
    }

    public var allowsTools: Bool {
        switch self { case .chat: false; case .build, .autonomous: true }
    }
}

/// 回复详细程度。
public enum LumiResponseVerbosity: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    case brief
    case standard
    case detailed

    /// 未显式指定时使用的默认级别（单一事实来源）。
    /// 所有回退到默认值的位置都应引用此处，避免各处不一致。
    public static let defaultVerbosity: LumiResponseVerbosity = .standard

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case .brief: "v1"
        case .standard: "v2"
        case .detailed: "v3"
        }
    }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "v1", "brief": self = .brief
        case "v2", "standard", "normal": self = .standard
        case "v3", "detailed": self = .detailed
        default: return nil
        }
    }

    public var levelCode: String { rawValue.uppercased() }

    public var displayName: String {
        switch self { case .brief: "简洁"; case .standard: "标准"; case .detailed: "详细" }
    }

    public var iconName: String {
        switch self {
        case .brief: "text.alignleft"
        case .standard: "text.justify.left"
        case .detailed: "doc.richtext"
        }
    }

    public var description: String {
        switch self {
        case .brief: "只返回核心结论"
        case .standard: "包含必要说明和步骤"
        case .detailed: "包含完整推理和上下文"
        }
    }
}

/// 请求级「具体推理档位」，与模型能力枚举（`LumiThinkingAndReasoning`）解耦：
/// 该类型描述用户本次请求的具体档位（low / medium / high / xhigh / max）。
public enum LumiReasoningEffort: String, CaseIterable, Codable, Identifiable, Sendable {
    case low
    case medium
    case high
    case xhigh
    case max

    public static let defaultEffort: LumiReasoningEffort = .high

    public var id: String { rawValue }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "low": self = .low
        case "medium": self = .medium
        case "high": self = .high
        case "xhigh": self = .xhigh
        case "max": self = .max
        default: return nil
        }
    }

    public var levelCode: String {
        switch self {
        case .low: "LOW"
        case .medium: "MED"
        case .high: "HIGH"
        case .xhigh: "XHIGH"
        case .max: "MAX"
        }
    }

    public var displayName: String {
        switch self {
        case .low: "低"
        case .medium: "中"
        case .high: "高"
        case .xhigh: "超高"
        case .max: "极限"
        }
    }

    public var iconName: String {
        switch self {
        case .low: "gauge.low"
        case .medium: "gauge.with.needle"
        case .high: "gauge.medium"
        case .xhigh: "gauge.high"
        case .max: "flame.fill"
        }
    }

    public var description: String {
        switch self {
        case .low: "轻量推理，适合简单问答"
        case .medium: "标准推理，适合一般任务"
        case .high: "深度推理，适合复杂代码和架构"
        case .xhigh: "更高推理预算，适合硬骨头"
        case .max: "最大推理预算，适合极致调试和难题"
        }
    }
}

/// 对话摘要：对话列表 / 侧边栏等轻量 UI 使用的数据模型。
public struct LumiConversationSummary: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String?
    public var preview: String
    public var createdAt: Date
    public var updatedAt: Date
    /// Timestamp of the last message received (used for conversation list sorting)
    public var lastMessageAt: Date
    public var verbosity: LumiResponseVerbosity?
    public var reasoningEffort: LumiReasoningEffort?
    public var language: LumiConversationLanguage?
    public var automationLevel: LumiAutomationLevel?
    public var providerID: String?
    public var modelName: String?
    public var projectPath: String?
    /// The conversation that spawned this conversation, if it was created by a sub-agent.
    public var parentConversationID: UUID?

    public init(
        id: UUID = UUID(),
        title: String? = nil,
        preview: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastMessageAt: Date? = nil,
        verbosity: LumiResponseVerbosity? = nil,
        reasoningEffort: LumiReasoningEffort? = nil,
        language: LumiConversationLanguage? = nil,
        automationLevel: LumiAutomationLevel? = nil,
        providerID: String? = nil,
        modelName: String? = nil,
        projectPath: String? = nil,
        parentConversationID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastMessageAt = lastMessageAt ?? createdAt
        self.verbosity = verbosity
        self.reasoningEffort = reasoningEffort
        self.language = language
        self.automationLevel = automationLevel
        self.providerID = providerID
        self.modelName = modelName
        self.projectPath = projectPath
        self.parentConversationID = parentConversationID
    }

    public var displayTitle: String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    public var hasCustomTitle: Bool {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !trimmed.isEmpty
    }
}
