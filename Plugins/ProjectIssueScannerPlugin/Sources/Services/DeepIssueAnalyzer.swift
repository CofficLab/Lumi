import Foundation
import LLMKit
import LLMKit
import LumiCoreKit
import LLMKit
import SuperLogKit

public protocol ProjectIssueScannerProviderType {
    static var hasApiKey: Bool { get }
}

public protocol ProjectIssueScannerLLMService: Sendable {
    func allProviders() -> [LLMProviderInfo]
    func providerType(forId id: String) -> (any ProjectIssueScannerProviderType.Type)?
    func sendMessage(messages: [ChatMessage], config: LLMConfig) async throws -> ChatMessage
}

/// 扫描器模型偏好
public enum ScannerModelPreference: Codable, Equatable, Hashable, Sendable {
    /// 使用自动路由选择最优模型
    case auto
    /// 使用用户手动指定的模型
    case manual(providerId: String, model: String)

    /// UserDefaults 键
    static let userDefaultsKey = "ProjectIssueScanner.ModelPreference"

    /// 从 UserDefaults 加载偏好设置
    public static func load() -> ScannerModelPreference {
        load(from: .standard)
    }

    static func load(from userDefaults: UserDefaults) -> ScannerModelPreference {
        guard let data = userDefaults.data(forKey: userDefaultsKey) else {
            return .auto
        }
        do {
            return try JSONDecoder().decode(ScannerModelPreference.self, from: data)
        } catch {
            userDefaults.removeObject(forKey: userDefaultsKey)
            return .auto
        }
    }

    /// 保存偏好设置到 UserDefaults
    public func save() {
        save(to: .standard)
    }

    @discardableResult
    func save(to userDefaults: UserDefaults) -> Bool {
        do {
            let data = try JSONEncoder().encode(self)
            userDefaults.set(data, forKey: Self.userDefaultsKey)
            return true
        } catch {
            return false
        }
    }

    /// 显示名称
    public var displayName: String {
        switch self {
        case .auto:
            return "Auto (自动选择)"
        case .manual(let providerId, let model):
            return "\(providerId) / \(model)"
        }
    }
}

/// LLM 深度问题分析器
///
/// 使用 LLM 对项目代码进行深度分析，发现潜在 bug、安全风险、性能问题等。
/// 支持自动模型路由或用户手动指定模型。
public actor DeepIssueAnalyzer: SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose = false

    public static let shared = DeepIssueAnalyzer()

    // MARK: - State

    private var llmService: (any ProjectIssueScannerLLMService)?

    /// 当前模型偏好
    private var modelPreference: ScannerModelPreference = .auto

    // MARK: - Public API

    /// 配置 LLM 服务（由 Root 视图调用）
    ///
    /// 通过 @EnvironmentObject 获取 AppLLMVM 后，调用此方法传递 LLM 服务引用。
    public func configure(llmService: any ProjectIssueScannerLLMService) {
        self.llmService = llmService
    }

    /// 更新模型偏好
    public func updateModelPreference(_ preference: ScannerModelPreference) {
        self.modelPreference = preference
    }

    /// 获取当前模型偏好
    public func getModelPreference() -> ScannerModelPreference {
        return modelPreference
    }

    /// LLM 服务是否已就绪
    public func isReady() -> Bool {
        guard let llmService else { return false }

        switch modelPreference {
        case .auto:
            // 自动模式需要至少有一个可用的供应商和模型
            return !llmService.allProviders().isEmpty
        case .manual(let providerId, let model):
            // 手动模式需要指定的供应商和模型存在
            guard let provider = llmService.allProviders().first(where: { $0.id == providerId }) else {
                return false
            }
            return provider.availableModels.contains(model)
        }
    }

    /// 对指定项目执行深度分析
    ///
    /// - Parameter projectPath: 项目根路径
    /// - Returns: 发现的问题列表，如果服务未就绪或分析失败则返回 nil
    public func analyze(projectPath: String) async -> [ProjectIssue]? {
        guard let llmService else {
            return nil
        }

        guard let config = resolveConfig(llmService: llmService) else {
            return nil
        }

        let context = collectProjectContext(projectPath: projectPath)
        guard !context.files.isEmpty else { return [] }

        let messages = [
            ChatMessage(role: .system, content: systemPrompt),
            ChatMessage(role: .user, content: userPrompt(context: context)),
        ]

        do {
            let response = try await llmService.sendMessage(messages: messages, config: config)
            return try parseIssues(response.content, projectPath: context.projectPath)
        } catch {
            return nil
        }
    }

    /// 根据模型偏好解析 LLM 配置
    private func resolveConfig(llmService: any ProjectIssueScannerLLMService) -> LLMConfig? {
        switch modelPreference {
        case .auto:
            return resolveAutoConfig(llmService: llmService)
        case .manual(let providerId, let model):
            return resolveManualConfig(llmService: llmService, providerId: providerId, model: model)
        }
    }

    /// 自动路由选择最优模型
    private func resolveAutoConfig(llmService: any ProjectIssueScannerLLMService) -> LLMConfig? {
        let candidates = collectRouteCandidates(llmService: llmService)
        let router = ModelRouter()

        let signal = RouteSignal(
            hasImages: false,
            messageLength: 0,
            allowsTools: false,
            currentProviderId: "",
            currentModel: ""
        )

        guard let decision = router.route(candidates: candidates, signal: signal) else {
            return nil
        }

        return LLMConfig(model: decision.model, providerId: decision.providerId)
    }

    /// 使用用户手动指定的模型
    private func resolveManualConfig(llmService: any ProjectIssueScannerLLMService, providerId: String, model: String) -> LLMConfig? {
        guard let provider = llmService.allProviders().first(where: { $0.id == providerId }),
              provider.availableModels.contains(model) else {
            return nil
        }

        return LLMConfig(model: model, providerId: providerId)
    }

    /// 收集路由候选模型
    private func collectRouteCandidates(llmService: any ProjectIssueScannerLLMService) -> [RouteCandidate] {
        return llmService.allProviders().flatMap { provider -> [RouteCandidate] in
            guard provider.isEnabled else { return [] }

            // 远程供应商必须有 API Key
            if !provider.isLocal,
               llmService.providerType(forId: provider.id)?.hasApiKey != true {
                return []
            }

            return provider.availableModels.compactMap { model -> RouteCandidate? in
                return RouteCandidate(
                    providerId: provider.id,
                    providerDisplayName: provider.displayName,
                    model: model,
                    availability: .unknown,
                    contextWindowSizes: provider.contextWindowSizes
                )
            }
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

                let content = try ProjectIssueTextReader.read(fileURL)
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
        ProjectIssuePathFormatter.relativePath(for: fileURL, rootURL: rootURL)
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
    public let projectPath: String
    public let files: [ProjectAnalysisFile]
}

private struct ProjectAnalysisFile: Sendable {
    public let path: String
    public let languageHint: String
    public let lineCount: Int
    public let excerpt: String
}

private struct DeepIssuePayload: Codable {
    public let issues: [DeepIssueItem]

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        issues = try container.decodeIfPresent([DeepIssueItem].self, forKey: .issues) ?? []
    }
}

private struct DeepIssueItem: Codable {
    public let type: String?
    public let severity: String?
    public let filePath: String?
    public let lineNumber: Int?
    public let title: String?
    public let description: String?
    public let suggestion: String?
}

private enum DeepIssueAnalyzerError: LocalizedError {
    case invalidJSONResponse

    public var errorDescription: String? {
        switch self {
        case .invalidJSONResponse:
            return "The model did not return valid issue JSON."
        }
    }
}
