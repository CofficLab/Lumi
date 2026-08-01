import Foundation

/// AskUser 的单个候选项。
///
/// 兼容两种形态：
/// - 裸字符串（如 `"是"`）—— 由 `label` 单独表达，`description` 为 nil。
/// - 结构化对象（如 `{"label":"方案A","description":"..."}`）—— 同时携带说明。
///
/// `label` 既是按钮文本，也是回传给 LLM 的 answer；`description` 仅用于展示。
public struct AskUserOption: Codable, Equatable, Sendable, Identifiable, Hashable {
    public let label: String
    public let description: String?

    public init(label: String, description: String? = nil) {
        self.label = label
        self.description = description
    }

    /// `Identifiable` 的 id 复用 label，保证 ForEach 行为稳定且与旧 `id: \.self` 一致。
    public var id: String { label }

    // MARK: - 自定义 Codable（兼容裸字符串与对象两种 wire 形态）

    private enum CodingKeys: String, CodingKey {
        case label, description
    }

    public init(from decoder: Decoder) throws {
        // 优先按对象解码；若输入是单个字符串，降级为只有 label 的选项。
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.label = try container.decode(String.self, forKey: .label)
            self.description = try container.decodeIfPresent(String.self, forKey: .description)
        } else {
            let container = try decoder.singleValueContainer()
            self.label = try container.decode(String.self)
            self.description = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        // description 为 nil 时编码为裸字符串，保持与旧 payload 一致的 wire 格式；
        // 有 description 时才编码为对象。
        if let description {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(label, forKey: .label)
            try container.encode(description, forKey: .description)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(label)
        }
    }
}

/// 等待用户响应的数据结构
///
/// AskUserTool 执行后返回 pending 状态时携带的 JSON payload，
/// 由渲染器解析并显示用户选择界面。
public struct AskUserPendingResponse: Codable, Equatable {
    public let toolCallId: String
    public let question: String
    public let options: [AskUserOption]
    /// 交互模式：`"yes_no"` / `"choice"` / `"free_text"`。
    /// 可选是为了兼容旧 payload（早期版本无此字段）；视图层会在 `nil` 时按 `options` 回退推断。
    public let mode: String?
    public let conversationId: String
    public let verbosity: String

    public init(
        toolCallId: String,
        question: String,
        options: [AskUserOption],
        mode: String?,
        conversationId: String,
        verbosity: String
    ) {
        self.toolCallId = toolCallId
        self.question = question
        self.options = options
        self.mode = mode
        self.conversationId = conversationId
        self.verbosity = verbosity
    }
}

/// AskUserTool 执行出错的错误响应数据结构
public struct AskUserErrorResponse: Codable, Equatable {
    public let error: String
}
