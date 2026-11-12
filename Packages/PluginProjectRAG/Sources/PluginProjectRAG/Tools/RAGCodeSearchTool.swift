import Foundation
import KitAgentTool
import ProviderProjectRAG

/// 新旧版本均使用 `search_code` 作为稳定的工具名，避免历史会话、提示词和
/// agent 配置在升级后失效。索引不存在或过期时先增量构建，再进行语义检索。
public struct RAGCodeSearchTool: SuperAgentTool {
    public static let toolName = "search_code"
    public let name = Self.toolName
    private let providerOverride: (any ProjectRAGProviding)?
    private let searchMemory: ProjectRAGSearchMemory?

    public init(provider: (any ProjectRAGProviding)? = nil) {
        self.init(provider: provider, searchMemory: nil)
    }

    init(provider: (any ProjectRAGProviding)? = nil, searchMemory: ProjectRAGSearchMemory?) {
        self.providerOverride = provider
        self.searchMemory = searchMemory
    }

    public func description(for language: LanguagePreference) -> String {
        "Search semantic code snippets in the current project or an explicitly supplied project path."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "A symbol, error, file path, or natural-language code query."],
                "project_path": ["type": "string", "description": "Optional project root. Defaults to the current project."],
                "top_k": ["type": "integer", "minimum": 1, "maximum": 20, "description": "Maximum result count; defaults to 8."],
            ],
            "required": ["query"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let query = (arguments["query"]?.value as? String ?? "code").prefix(40)
        return "Search code: \(query)"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        ToolCallResult(content: try await execute(
            arguments: arguments,
            conversationProjectPath: await context.conversationProjectPath()
        ))
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await execute(arguments: arguments, conversationProjectPath: nil)
    }

    private func execute(
        arguments: [String: ToolArgument],
        conversationProjectPath: String?
    ) async throws -> String {
        guard let query = (arguments["query"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !query.isEmpty else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Missing required `query` parameter.")
        }
        let explicitPath = (arguments["project_path"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPath = await MainActor.run { ProjectRAGRuntime.provider?.currentProjectPath }
        // 优先显式参数，其次工具调用所属会话绑定的项目，最后回退到 UI 当前项目。
        let projectPath = explicitPath?.isEmpty == false
            ? explicitPath
            : conversationProjectPath ?? currentPath
        guard let projectPath, !projectPath.isEmpty else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Open a project or provide `project_path`.")
        }
        guard FileManager.default.fileExists(atPath: projectPath) else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Project path does not exist: `\(projectPath)`")
        }
        let provider: (any ProjectRAGProviding)?
        if let providerOverride {
            provider = providerOverride
        } else {
            provider = await MainActor.run(body: { ProjectRAGRuntime.provider })
        }
        guard let provider else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Project RAG is not available.")
        }
        if let searchMemory,
           await searchMemory.consumeRecentAutomaticSearch(query: query, projectPath: projectPath) {
            return "## Code Search\n\nThe matching project evidence was already injected into the current LLM context; no duplicate results were returned."
        }

        // 安全解析 + 钳制：越界/非有限/非数字参数退回默认或钳到边界，绝不 trap 宿主进程。
        let topK = arguments.toolInt("top_k", clampedTo: 1...20, default: 8)
        let response = try await CodeNavigationCoordinator(provider: provider).search(
            query: query,
            projectPath: projectPath,
            topK: topK
        )
        guard !response.results.isEmpty else {
            return "## Code Search\n\nNo code matched `\(query)`. If the project was just opened, indexing may still be in progress; try grep for exact text."
        }
        return response.results.enumerated().map { index, result in
            let score = String(format: "%.2f", result.score)
            let lineLabel = result.lineRange.map { ":\($0.startLine)-\($0.endLine)" } ?? ""
            return "### \(index + 1). `\(result.source)\(lineLabel)` (score: \(score), evidence: \(result.matchKind.rawValue))\n\n```\n\(result.content)\n```"
        }.joined(separator: "\n\n")
    }
}
