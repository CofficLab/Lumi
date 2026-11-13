import Foundation
import KitAgentTool
import ProjectRAGEngine

/// 实时内容搜索工具：忠实执行正则，不依赖索引。与 `search_code`（语义兜底）
/// 分工：符号、错误串、字面量优先走这里。
public struct RAGGrepTool: SuperAgentTool {
    public static let toolName = "grep"
    public let name = Self.toolName

    // 每次调用独立 ripgrep 进程（协作池外执行），无共享可变状态，可并行。
    public var executionCapability: ToolExecutionCapability { .parallelReadOnly }

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "在项目文件中做精确文本/正则搜索（ripgrep），不需要索引，索引进行中也可用。查找符号、错误串、字面量时优先使用；语义模糊的问题用 search_code。"
        case .english:
            return "Exact text/regex search across project files via ripgrep. Works without any index, even while indexing runs. Prefer it for symbols, error strings, and literals; use search_code for fuzzy semantic questions."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "pattern": ["type": "string", "description": "ripgrep regular expression, passed through verbatim."],
                "path": ["type": "string", "description": "Optional project root. Defaults to the current project."],
                "glob": ["type": "string", "description": "Optional file glob filter, e.g. *.swift."],
                "case_insensitive": ["type": "boolean", "description": "Case-insensitive matching; defaults to false."],
                "max_results": ["type": "integer", "minimum": 1, "maximum": 500, "description": "Maximum matches returned; defaults to 100."],
                "context_lines": ["type": "integer", "minimum": 0, "maximum": 10, "description": "Context lines around each match; defaults to 0."],
            ],
            "required": ["pattern"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let pattern = (arguments["pattern"]?.value as? String ?? "pattern").prefix(40)
        return "Grep: \(pattern)"
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
        guard let pattern = (arguments["pattern"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !pattern.isEmpty else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Missing required `pattern` parameter.")
        }
        let explicitPath = (arguments["path"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPath = await MainActor.run { ProjectRAGRuntime.provider?.currentProjectPath }
        // 优先显式参数，其次工具调用所属会话绑定的项目，最后回退到 UI 当前项目。
        let projectPath = explicitPath?.isEmpty == false
            ? explicitPath
            : conversationProjectPath ?? currentPath
        guard let projectPath, !projectPath.isEmpty else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Open a project or provide `path`.")
        }
        guard FileManager.default.fileExists(atPath: projectPath) else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Project path does not exist: `\(projectPath)`")
        }

        let glob = (arguments["glob"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let caseInsensitive: Bool
        switch arguments["case_insensitive"]?.value {
        case let value as Bool: caseInsensitive = value
        case let value as String: caseInsensitive = value.lowercased() == "true"
        default: caseInsensitive = false
        }
        // 安全解析 + 钳制：越界/非有限/非数字参数退回默认或钳到边界，绝不 trap 宿主进程。
        let maxResults = arguments.toolInt("max_results", clampedTo: 1...500, default: 100)
        let contextLines = arguments.toolInt("context_lines", clampedTo: 0...10, default: 0)

        let outcome: RAGGrepOutcome
        do {
            outcome = try await RAGGrepSearcher.search(
                pattern: pattern,
                projectPath: projectPath,
                glob: glob?.isEmpty == false ? glob : nil,
                caseInsensitive: caseInsensitive,
                maxResults: maxResults,
                contextLines: contextLines
            )
        } catch let error as RAGGrepError {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: error.errorDescription ?? "grep failed."
            )
        }
        guard outcome.totalMatchCount > 0 else {
            return "No matches for pattern `\(pattern)`."
        }
        return RAGGrepSearcher.formatOutput(outcome, projectPath: projectPath)
    }
}