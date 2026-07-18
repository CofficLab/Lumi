import Foundation

public enum LumiResponseVerbosity: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    case brief
    case standard
    case detailed

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case .brief:
            "v1"
        case .standard:
            "v2"
        case .detailed:
            "v3"
        }
    }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "v1", "brief":
            self = .brief
        case "v2", "standard", "normal":
            self = .standard
        case "v3", "detailed":
            self = .detailed
        default:
            return nil
        }
    }

    public var levelCode: String {
        rawValue.uppercased()
    }

    public var displayName: String {
        switch self {
        case .brief:
            "简洁"
        case .standard:
            "标准"
        case .detailed:
            "详细"
        }
    }

    public var iconName: String {
        switch self {
        case .brief:
            "text.alignleft"
        case .standard:
            "text.justify.left"
        case .detailed:
            "doc.richtext"
        }
    }

    public var description: String {
        switch self {
        case .brief:
            "只返回核心结论"
        case .standard:
            "包含必要说明和步骤"
        case .detailed:
            "包含完整推理和上下文"
        }
    }
}

public enum LumiConversationLanguage: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    case chinese
    case english

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case .chinese:
            "zh"
        case .english:
            "en"
        }
    }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "zh", "chinese", "cn":
            self = .chinese
        case "en", "english":
            self = .english
        default:
            return nil
        }
    }

    public var shortCode: String {
        switch self {
        case .chinese:
            "中"
        case .english:
            "EN"
        }
    }

    public var displayName: String {
        switch self {
        case .chinese:
            "中文"
        case .english:
            "English"
        }
    }

    public var iconName: String {
        "character.book.closed"
    }
}

public enum LumiAutomationLevel: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    case chat
    case build
    case autonomous

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case .chat:
            "a1"
        case .build:
            "a2"
        case .autonomous:
            "a3"
        }
    }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "a1", "chat":
            self = .chat
        case "a2", "build":
            self = .build
        case "a3", "autonomous":
            self = .autonomous
        default:
            return nil
        }
    }

    public var levelCode: String {
        rawValue.uppercased()
    }

    public var displayName: String {
        switch self {
        case .chat:
            "对话"
        case .build:
            "构建"
        case .autonomous:
            "自主"
        }
    }

    public var iconName: String {
        switch self {
        case .chat:
            "bubble.left.and.bubble.right"
        case .build:
            "hammer.fill"
        case .autonomous:
            "bolt.shield.fill"
        }
    }

    public var description: String {
        switch self {
        case .chat:
            "只进行对话，不执行任何工具"
        case .build:
            "可以执行工具，高风险需要确认"
        case .autonomous:
            "可以自主执行工具，持续推进任务"
        }
    }

    public var allowsTools: Bool {
        switch self {
        case .chat:
            false
        case .build, .autonomous:
            true
        }
    }
}

public struct LumiConversationSummary: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var preview: String
    public var createdAt: Date
    public var updatedAt: Date
    public var verbosity: LumiResponseVerbosity?
    public var language: LumiConversationLanguage?
    public var automationLevel: LumiAutomationLevel?
    public var providerID: String?
    public var modelName: String?
    public var projectPath: String?

    public init(
        id: UUID = UUID(),
        title: String,
        preview: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        verbosity: LumiResponseVerbosity? = nil,
        language: LumiConversationLanguage? = nil,
        automationLevel: LumiAutomationLevel? = nil,
        providerID: String? = nil,
        modelName: String? = nil,
        projectPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.verbosity = verbosity
        self.language = language
        self.automationLevel = automationLevel
        self.providerID = providerID
        self.modelName = modelName
        self.projectPath = projectPath
    }
}

public enum LumiModelRoutingMode: String, Codable, Sendable, CaseIterable {
    case manual
    case auto
}
