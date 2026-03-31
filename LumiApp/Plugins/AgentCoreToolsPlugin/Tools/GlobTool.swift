import Foundation
import MagicKit

/// Glob 工具（纯 Swift 原生实现）
///
/// 使用 FileManager.enumerator + NSRegularExpression 匹配文件名。
/// 零外部依赖，不需要 ripgrep 或其他工具。
///
/// 支持：
/// - 通配符匹配（*, **, ?, [...]）
/// - 花括号展开（{a,b,c}）
/// - 路径搜索
/// - 按修改时间排序
/// - 结果截断
struct GlobTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔎"
    nonisolated static let verbose = false

    let name = "glob"
    let description = """
Find files matching a glob pattern. Useful for discovering files in a project by name or extension.

Pattern examples:
- `**/*.swift` — all Swift files recursively
- `src/**/*.ts` — all TypeScript files under src/
- `*.{json,yaml,yml}` — all config files
- `**/test_*.py` — all Python test files
- `README*` — all files starting with README

The search is case-sensitive. Use `path` to narrow the search to a specific directory.
"""

    var inputSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "pattern": [
                    "type": "string",
                    "description": "The glob pattern to match files against (e.g., \"**/*.swift\", \"*.{json,yaml}\")"
                ],
                "path": [
                    "type": "string",
                    "description": "The directory to search in. Defaults to current working directory. Must be a valid directory path if provided."
                ]
            ],
            "required": ["pattern"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let pattern = arguments["pattern"]?.value as? String else {
            return "Error: Missing required argument 'pattern'."
        }

        let path = arguments["path"]?.value as? String
        let searchPath: String
        if let path = path {
            searchPath = (path as NSString).expandingTildeInPath
        } else {
            searchPath = FileManager.default.currentDirectoryPath
        }

        let fileManager = FileManager.default

        // 验证路径存在且是目录
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: searchPath, isDirectory: &isDir), isDir.boolValue else {
            return "Error: Directory does not exist: \(searchPath)"
        }

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)glob '\(pattern)' in \(searchPath)")
        }

        let maxResults = 100

        // 枚举所有文件
        let allFiles = enumerateFiles(in: searchPath, maxResults: nil)

        // 用 glob 模式过滤
        var matchedFiles: [(absolute: String, relative: String)] = []
        for file in allFiles {
            if matchedFiles.count >= maxResults { break }
            if matchesGlobPattern(pattern, path: file.relative) {
                matchedFiles.append(file)
            }
        }

        if matchedFiles.isEmpty {
            return "No files found matching pattern: \(pattern)"
        }

        // 按修改时间排序（最新优先）
        let sorted = matchedFiles.sorted { a, b in
            let mtimeA = (try? fileManager.attributesOfItem(atPath: a.absolute)[.modificationDate] as? Date) ?? .distantPast
            let mtimeB = (try? fileManager.attributesOfItem(atPath: b.absolute)[.modificationDate] as? Date) ?? .distantPast
            return mtimeA > mtimeB
        }

        // 限制最大数量
        let results = Array(sorted.prefix(maxResults))
        let relativePaths = results.map(\.relative)

        var output = relativePaths.joined(separator: "\n")

        if matchedFiles.count >= maxResults {
            output += "\n\n(Results are truncated at \(maxResults) files. Consider using a more specific path or pattern.)"
        }

        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)found \(results.count) files")
        }

        return output
    }
}
