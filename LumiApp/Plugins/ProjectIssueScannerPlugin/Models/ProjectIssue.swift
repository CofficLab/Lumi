import Foundation

/// 项目问题模型
///
/// 表示扫描器在项目中发现的一个潜在问题。
/// 包含问题类型、严重程度、状态、文件位置和描述等信息。
struct ProjectIssue: Identifiable, Codable, Sendable {
    let id: UUID
    let type: ProjectIssueType
    let severity: ProjectIssueSeverity
    var status: ProjectIssueStatus
    let projectPath: String
    let filePath: String
    let lineNumber: Int?
    let title: String
    let description: String
    let suggestion: String?
    let source: ProjectIssueSource
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        type: ProjectIssueType,
        severity: ProjectIssueSeverity,
        status: ProjectIssueStatus = .pending,
        projectPath: String,
        filePath: String,
        lineNumber: Int?,
        title: String,
        description: String,
        suggestion: String?,
        source: ProjectIssueSource,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.status = status
        self.projectPath = projectPath
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.title = title
        self.description = description
        self.suggestion = suggestion
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case severity
        case status
        case projectPath
        case filePath
        case lineNumber
        case title
        case description
        case suggestion
        case source
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ProjectIssueType.self, forKey: .type)
        severity = try container.decode(ProjectIssueSeverity.self, forKey: .severity)
        status = try container.decode(ProjectIssueStatus.self, forKey: .status)
        projectPath = try container.decodeIfPresent(String.self, forKey: .projectPath) ?? ""
        filePath = try container.decode(String.self, forKey: .filePath)
        lineNumber = try container.decodeIfPresent(Int.self, forKey: .lineNumber)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        suggestion = try container.decodeIfPresent(String.self, forKey: .suggestion)
        source = try container.decode(ProjectIssueSource.self, forKey: .source)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

// MARK: - Enums

enum ProjectIssueType: String, Codable, Sendable, CaseIterable {
    case todo = "todo"
    case fixme = "fixme"
    case hack = "hack"
    case emptyCatch = "empty-catch"
    case largeFile = "large-file"
    case missingTest = "missing-test"
    case codeSmell = "code-smell"
    case potentialBug = "potential-bug"
    case securityRisk = "security-risk"
    case performance = "performance"
    case maintainability = "maintainability"
}

enum ProjectIssueSeverity: String, Codable, Sendable, CaseIterable {
    case critical = "critical"
    case warning = "warning"
    case info = "info"
}

enum ProjectIssueStatus: String, Codable, Sendable {
    case pending = "pending"
    case confirmed = "confirmed"
    case dismissed = "dismissed"
    case fixed = "fixed"
}

enum ProjectIssueSource: String, Codable, Sendable {
    /// 本地规则扫描（零成本）
    case localRule = "local-rule"
    /// LLM 深度分析（有成本）
    case llmAnalysis = "llm-analysis"
}

// MARK: - Convenience

extension ProjectIssue {
    /// 是否仍然需要关注（未修复且未忽略）
    var isOpen: Bool {
        status == .pending || status == .confirmed
    }

    /// 用于去重的唯一键（类型 + 文件 + 行号 + 来源）
    var dedupeKey: String {
        "\(projectPath)#\(type.rawValue)#\(filePath)#\(lineNumber ?? -1)#\(source.rawValue)"
    }
}
