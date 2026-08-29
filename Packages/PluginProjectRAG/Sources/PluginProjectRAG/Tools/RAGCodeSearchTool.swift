import Foundation
import KitAgentTool
import ProviderProjectRAG

/// 新旧版本均使用 `search_code` 作为稳定的工具名，避免历史会话、提示词和
/// agent 配置在升级后失效。索引不存在或过期时先增量构建，再进行语义检索。
public struct RAGCodeSearchTool: SuperAgentTool {
    public static let toolName = "search_code"
    public let name = Self.toolName

    public init() {}

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

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let query = (arguments["query"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !query.isEmpty else {
            return "## Code Search\n\nMissing required `query` parameter."
        }
        let explicitPath = (arguments["project_path"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectPath = explicitPath?.isEmpty == false
            ? explicitPath
            : await MainActor.run { ProjectRAGRuntime.provider?.currentProjectPath }
        guard let projectPath, !projectPath.isEmpty else {
            return "## Code Search\n\nOpen a project or provide `project_path`."
        }
        guard FileManager.default.fileExists(atPath: projectPath) else {
            return "## Code Search\n\nProject path does not exist: `\(projectPath)`"
        }
        guard let provider = await MainActor.run(body: { ProjectRAGRuntime.provider }) else {
            return "## Code Search\n\nProject RAG is not available."
        }

        let topK = min(max((arguments["top_k"]?.value as? Int) ?? 8, 1), 20)
        let hasIndex = try await provider.indexStatus(projectPath: projectPath) != nil
        let isIndexing = await provider.isIndexing(projectPath: projectPath)
        if !hasIndex && !isIndexing {
            try await provider.ensureIndexed(projectPath: projectPath, force: false, background: false)
        } else {
            try await provider.ensureIndexed(projectPath: projectPath, force: false, background: true)
        }
        let response = try await provider.search(query: query, projectPath: projectPath, topK: topK)
        guard !response.results.isEmpty else {
            return "## Code Search\n\nNo indexed code matched `\(query)`. Indexing may still be in progress."
        }
        return response.results.enumerated().map { index, result in
            let score = String(format: "%.2f", result.score)
            let lineLabel = result.lineRange.map { ":\($0.startLine)-\($0.endLine)" } ?? ""
            return "### \(index + 1). `\(result.source)\(lineLabel)` (score: \(score), evidence: \(result.matchKind.rawValue))\n\n```\n\(result.content)\n```"
        }.joined(separator: "\n\n")
    }
}
