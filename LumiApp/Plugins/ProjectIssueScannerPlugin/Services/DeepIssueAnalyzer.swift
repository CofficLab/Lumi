import Foundation
import LLMKit
import MagicKit

/// LLM 深度问题分析器
///
/// 使用 LLM 对项目代码进行深度分析，发现潜在 bug、安全风险、性能问题等。
/// LLM 服务通过 Root 视图的 @EnvironmentObject 获取，传递给本分析器。
actor DeepIssueAnalyzer: SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose = false

    static let shared = DeepIssueAnalyzer()

    // MARK: - State

    private var llmService: LLMService?
    private var config: LLMConfig?

    // MARK: - Public API

    /// 配置 LLM 服务（由 Root 视图调用）
    ///
    /// 通过 @EnvironmentObject 获取 AppLLMVM 后，调用此方法传递 LLM 服务引用。
    func configure(llmService: LLMService, config: LLMConfig) {
        self.llmService = llmService
        self.config = config
    }

    /// LLM 服务是否已就绪
    func isReady() -> Bool {
        llmService != nil
    }

    /// 对指定项目执行深度分析
    ///
    /// - Parameter projectPath: 项目根路径
    /// - Returns: 发现的问题列表，如果服务未就绪或分析失败则返回 nil
    func analyze(projectPath: String) async -> [ProjectIssue]? {
        guard let llmService, let config else {
            return nil
        }

        let context = collectProjectContext(projectPath: projectPath)
        guard !context.files.isEmpty else { return [] }

        let conversationId = UUID()
        let messages = [
            ChatMessage(role: .system, conversationId: conversationId, content: systemPrompt),
            ChatMessage(role: .user, conversationId: conversationId, content: userPrompt(context: context))
        ]

        do {
            let response = try await llmService.sendMessage(messages: messages, config: config)
            return try parseIssues(response.content, projectPath: context.projectPath)
        } catch {
            return nil
        }
    }

    // MARK: - Prompts

    private var systemPrompt: String {
        """
        You are a senior software engineer scanning a project during idle time.
        Find only concrete, actionable risks likely to matter later: potential bugs, security risks, performance problems, missing tests, or maintainability issues.
        Do not report TODO, FIXME, HACK, formatting, style-only issues, or anything already obvious from a simple grep.
        Return only valid JSON. Do not wrap it in Markdown.

        JSON schema:
        {
          "issues": [
            {
              "type": "missing-test|code-smell|potential-bug|security-risk|performance|maintainability",
              "severity": "critical|warning|info",
              "filePath": "relative/path",
              "lineNumber": 12,
              "title": "short title",
              "description": "what is wrong and why it matters",
              "suggestion": "specific next action"
            }
          ]
        }
        """
    }

    private func userPrompt(context: ProjectAnalysisContext) -> String {
        """
        Project path: \(context.projectPath)

        Files sampled:
        \(context.files.map { "- \($0.path) (\($0.lineCount) lines)" }.joined(separator: "\n"))

        File excerpts:
        \(context.files.map { file in
            """
            ## \(file.path)
            ```\(file.languageHint)
            \(file.excerpt)
            ```
            """
        }.joined(separator: "\n\n"))
        """
    }

    // MARK: - Context

    private func collectProjectContext(projectPath: String) -> ProjectAnalysisContext {
        let rootURL = URL(fileURLWithPath: projectPath).standardizedFileURL
        let fileManager = FileManager.default
        let ignoredDirectories: Set<String> = [
            ".git", "node_modules", ".build", "DerivedData", ".swiftpm",
            "Pods", ".gradle", "build", ".venv", "__pycache__", ".next", "dist"
        ]
        let preferredExtensions: Set<String> = [
            "swift", "ts", "tsx", "js", "jsx", "vue", "py", "go", "rs", "kt", "java"
        ]

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ProjectAnalysisContext(projectPath: rootURL.path, files: [])
        }

        var candidates: [ProjectAnalysisFile] = []

        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey])
                if values.isDirectory == true {
                    if ignoredDirectories.contains(fileURL.lastPathComponent) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                guard values.isRegularFile == true else { continue }
                guard preferredExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
                guard (values.fileSize ?? 0) <= 256 * 1024 else { continue }

                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                let excerpt = summarizeContent(lines: lines)
                guard !excerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

                candidates.append(ProjectAnalysisFile(
                    path: relativePath(for: fileURL, rootURL: rootURL),
                    languageHint: fileURL.pathExtension.lowercased(),
                    lineCount: lines.count,
                    excerpt: excerpt
                ))
            } catch {
                continue
            }
        }

        let selected = candidates
            .sorted { lhs, rhs in
                if lhs.lineCount == rhs.lineCount {
                    return lhs.path < rhs.path
                }
                return lhs.lineCount > rhs.lineCount
            }
            .prefix(8)

        return ProjectAnalysisContext(projectPath: rootURL.path, files: Array(selected))
    }

    private func summarizeContent(lines: [String]) -> String {
        let maxLines = 180
        guard lines.count > maxLines else {
            return lines.joined(separator: "\n")
        }

        let head = lines.prefix(100)
        let tail = lines.suffix(80)
        return (head + ["// ... truncated for idle analysis ..."] + tail).joined(separator: "\n")
    }

    private func relativePath(for fileURL: URL, rootURL: URL) -> String {
        let rootPath = rootURL.path
        let filePath = fileURL.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else { return filePath }

        let start = filePath.index(filePath.startIndex, offsetBy: rootPath.count)
        return String(filePath[start...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    // MARK: - Parsing

    private func parseIssues(_ content: String, projectPath: String) throws -> [ProjectIssue] {
        let json = try extractJSONObject(from: content)
        let data = Data(json.utf8)
        let payload = try JSONDecoder().decode(DeepIssuePayload.self, from: data)
        let now = Date()

        return payload.issues.prefix(12).compactMap { issue in
            guard let filePath = issue.filePath?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !filePath.isEmpty else {
                return nil
            }

            return ProjectIssue(
                type: ProjectIssueType(rawValue: issue.type ?? "") ?? .codeSmell,
                severity: ProjectIssueSeverity(rawValue: issue.severity ?? "") ?? .info,
                projectPath: projectPath,
                filePath: filePath,
                lineNumber: issue.lineNumber,
                title: nonEmpty(issue.title) ?? "Potential issue",
                description: nonEmpty(issue.description) ?? "The analyzer found a potential issue.",
                suggestion: nonEmpty(issue.suggestion),
                source: .llmAnalysis,
                createdAt: now,
                updatedAt: now
            )
        }
    }

    private func extractJSONObject(from content: String) throws -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return trimmed
        }

        guard let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") else {
            throw DeepIssueAnalyzerError.invalidJSONResponse
        }

        return String(trimmed[start...end])
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct ProjectAnalysisContext: Sendable {
    let projectPath: String
    let files: [ProjectAnalysisFile]
}

private struct ProjectAnalysisFile: Sendable {
    let path: String
    let languageHint: String
    let lineCount: Int
    let excerpt: String
}

private struct DeepIssuePayload: Codable {
    let issues: [DeepIssueItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        issues = try container.decodeIfPresent([DeepIssueItem].self, forKey: .issues) ?? []
    }
}

private struct DeepIssueItem: Codable {
    let type: String?
    let severity: String?
    let filePath: String?
    let lineNumber: Int?
    let title: String?
    let description: String?
    let suggestion: String?
}

private enum DeepIssueAnalyzerError: LocalizedError {
    case invalidJSONResponse

    var errorDescription: String? {
        switch self {
        case .invalidJSONResponse:
            return "The model did not return valid issue JSON."
        }
    }
}
