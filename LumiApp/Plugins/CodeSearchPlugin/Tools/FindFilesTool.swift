import Foundation
import MagicKit
import OSLog

/// 文件查找工具
///
/// 按 glob 模式查找文件。
struct FindFilesTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose = true

    let name = "find_files"
    let description = "按 glob 模式查找文件，例如 `**/*.swift` 查找所有 Swift 文件。支持排除模式。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "pattern": [
                    "type": "string",
                    "description": "Glob 模式，如 '**/*.swift' 或 'src/**/*.ts'"
                ],
                "path": [
                    "type": "string",
                    "description": "搜索目录，默认为当前工作目录"
                ],
                "exclude": [
                    "type": "string",
                    "description": "排除模式，如 'node_modules/**' 或 '*.test.*'"
                ],
                "maxResults": [
                    "type": "number",
                    "description": "最大返回结果数，默认 100，最大 500"
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
        let exclude = arguments["exclude"]?.value as? String
        let maxResults = min(arguments["maxResults"]?.value as? Int ?? 100, 500)

        if Self.verbose {
            os_log("\(Self.t)查找文件：pattern=\(pattern) path=\(path ?? ".")")
        }

        do {
            let files = try await CodeSearchService.shared.findFiles(
                pattern: pattern,
                path: path,
                exclude: exclude,
                maxResults: maxResults
            )
            return formatFiles(files)
        } catch {
            os_log(.error, "\(Self.t)文件查找失败：\(error.localizedDescription)")
            return "文件查找失败：\(error.localizedDescription)"
        }
    }

    private func formatFiles(_ files: [String]) -> String {
        guard !files.isEmpty else {
            return "未找到匹配的文件"
        }

        var output = "## 文件查找结果\n\n"
        output += "找到 **\(files.count)** 个文件\n\n"

        // 按文件类型分组统计
        var typeCounts: [String: Int] = [:]
        for file in files {
            let ext = (file as NSString).pathExtension
            let key = ext.isEmpty ? "(无扩展名)" : ".\(ext)"
            typeCounts[key, default: 0] += 1
        }

        output += "**文件类型分布**:\n"
        for (type, count) in typeCounts.sorted(by: { $1.value < $0.value }) {
            output += "- \(type): \(count)\n"
        }
        output += "\n---\n\n"

        output += "**文件列表**:\n\n"
        for file in files {
            output += "- `\(file)`\n"
        }

        return output
    }
}
