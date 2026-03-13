import Foundation
import MagicKit
import OSLog

/// 代码搜索工具
///
/// 在代码库中搜索包含特定模式的内容。
struct CodeSearchTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔎"
    nonisolated static let verbose = true

    let name = "code_search"
    let description = "在代码库中搜索包含特定文本或模式的文件。支持正则表达式、文件类型过滤。返回包含匹配行号和上下文的详细信息。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "pattern": [
                    "type": "string",
                    "description": "搜索模式，支持正则表达式"
                ],
                "path": [
                    "type": "string",
                    "description": "搜索目录，默认为当前工作目录"
                ],
                "filePattern": [
                    "type": "string",
                    "description": "文件匹配模式，如 '*.swift' 或 '*.ts'"
                ],
                "excludePattern": [
                    "type": "string",
                    "description": "排除的文件模式，如 'node_modules/*'"
                ],
                "ignoreCase": [
                    "type": "boolean",
                    "description": "是否忽略大小写，默认 false"
                ],
                "context": [
                    "type": "number",
                    "description": "显示匹配行上下文的行数，默认 2"
                ],
                "maxResults": [
                    "type": "number",
                    "description": "最大返回结果数，默认 50，最大 200"
                ]
            ],
            "required": ["pattern"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel? {
        // 只读操作，低风险
        return .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let pattern = arguments["pattern"]?.value as? String else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：pattern"]
            )
        }

        let path = arguments["path"]?.value as? String
        let filePattern = arguments["filePattern"]?.value as? String
        let excludePattern = arguments["excludePattern"]?.value as? String
        let ignoreCase = arguments["ignoreCase"]?.value as? Bool ?? false
        let context = arguments["context"]?.value as? Int ?? 2
        let maxResults = min(arguments["maxResults"]?.value as? Int ?? 50, 200)

        if Self.verbose {
            os_log("\(Self.t)搜索代码：pattern=\(pattern) path=\(path ?? ".") filePattern=\(filePattern ?? "*")")
        }

        do {
            let results = try await CodeSearchService.shared.search(
                pattern: pattern,
                path: path,
                filePattern: filePattern,
                excludePattern: excludePattern,
                ignoreCase: ignoreCase,
                contextLines: context,
                maxResults: maxResults
            )
            return formatResults(results, pattern: pattern)
        } catch {
            os_log(.error, "\(Self.t)代码搜索失败：\(error.localizedDescription)")
            return "代码搜索失败：\(error.localizedDescription)"
        }
    }

    private func formatResults(_ results: [SearchResult], pattern: String) -> String {
        guard !results.isEmpty else {
            return "未找到匹配 '\(pattern)' 的结果"
        }

        var output = "## 代码搜索结果\n\n"
        output += "找到 **\(results.count)** 个匹配项\n\n"
        output += "搜索模式：`\(pattern)`\n\n"
        output += "---\n\n"

        for (index, result) in results.enumerated() {
            output += "### \(index + 1). `\(result.relativePath)`\n\n"

            for match in result.matches {
                output += "**第 \(match.lineNumber) 行**:\n"
                output += "```\(result.language ?? "text")\n"

                // 显示上下文
                if let contextBefore = match.contextBefore {
                    for line in contextBefore {
                        output += "  \(line)\n"
                    }
                }

                // 高亮匹配行
                output += "→ \(match.line)\n"

                if let contextAfter = match.contextAfter {
                    for line in contextAfter {
                        output += "  \(line)\n"
                    }
                }

                output += "```\n\n"
            }

            output += "---\n\n"
        }

        return output
    }
}

// MARK: - Search Result Models

struct SearchResult: Codable {
    let filePath: String
    let relativePath: String
    var matches: [Match]
    let language: String?
}

struct Match: Codable {
    let lineNumber: Int
    let line: String
    var contextBefore: [String]?
    var contextAfter: [String]?
}
