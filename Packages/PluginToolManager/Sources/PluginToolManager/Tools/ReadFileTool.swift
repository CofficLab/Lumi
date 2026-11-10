import KitAgentTool
import Foundation

/// 按行读取文件，支持 offset/limit 与截断。
public struct ReadFileTool: SuperAgentTool, @unchecked Sendable {
    public let name = "read_file"
    public let executionCapability: ToolExecutionCapability = .parallelReadOnly

    private static let maxWholeFileBytes: Int64 = 10 * 1024 * 1024
    private static let defaultLineLimit = 250
    private static let maxLineLimit = 250
    private let workspaceRootProvider: @MainActor @Sendable () -> String?

    public init(
        workspaceRootProvider: @escaping @MainActor @Sendable () -> String? = { nil }
    ) {
        self.workspaceRootProvider = workspaceRootProvider
    }

    public func description(for language: LanguagePreference) -> String {
        "Read UTF-8 text from a file by line range. Large files should be read in chunks with offset and limit."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "The absolute or workspace-relative path to the UTF-8 text file to read"],
                "offset": ["type": "integer", "description": "1-based line number to start reading from. Negative values count backwards from the end (e.g. -1 is the last line)."],
                "limit": ["type": "integer", "minimum": 1, "maximum": 250, "description": "Maximum number of lines to return. Defaults to 250 and is capped at 250 per request."],
            ],
            "required": ["path"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let path = arguments.stringValue("path") else { return "读取文件" }
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        // 审批/渲染阶段先于执行：这里的整型读取同样必须安全，
        // 越界或非有限的参数只能降级为「不展示」，不能在 UI 线程 trap。
        if let offset = arguments.toolInt("offset") {
            if let limit = arguments.toolInt("limit") {
                return "读取 \(fileName)（第 \(offset) 行起，最多 \(limit) 行）"
            }
            return "读取 \(fileName)（从第 \(offset) 行起）"
        }
        return "读取 \(fileName)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await execute(arguments: arguments, workspaceRootOverride: nil)
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        let workspaceRoot = await context.conversationProjectPath()
        let content = try await execute(arguments: arguments, workspaceRootOverride: workspaceRoot)
        return ToolCallResult(content: content)
    }

    private func execute(
        arguments: [String: ToolArgument],
        workspaceRootOverride: String?
    ) async throws -> String {
        guard let path = arguments.stringValue("path") else {
            throw NSError(domain: "ReadFileTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"])
        }

        let defaultRoot = await workspaceRootProvider()
        let url = WorkspacePathResolver.resolve(
            path: path,
            workspaceRoot: workspaceRootOverride ?? defaultRoot
        )
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard fileSize <= Self.maxWholeFileBytes else {
                throw ToolExecutionError.executionFailed(
                    toolName: name,
                    reason: "File is too large (\(fileSize) bytes; maximum is \(Self.maxWholeFileBytes) bytes). Read it in chunks."
                )
            }

            let rawText = try String(contentsOf: url, encoding: .utf8)
            let lines = rawText.components(separatedBy: "\n")
            let totalLines = lines.count

            let requestedOffset = arguments.toolInt("offset")
            let requestedLimit = arguments.toolInt("limit")

            // 越界 / NaN / 非有限值无法安全表示，必须作为参数错误抛出。
            if arguments["offset"]?.value != nil, requestedOffset == nil {
                throw ToolExecutionError.executionFailed(toolName: name, reason: "'offset' must be an integer line number.")
            }
            if arguments["limit"]?.value != nil, requestedLimit == nil {
                throw ToolExecutionError.executionFailed(toolName: name, reason: "'limit' must be a positive integer.")
            }
            if let requestedLimit, requestedLimit <= 0 {
                throw ToolExecutionError.executionFailed(toolName: name, reason: "'limit' must be a positive integer.")
            }

            let limit = min(requestedLimit ?? Self.defaultLineLimit, Self.maxLineLimit)
            let startIndex: Int
            if let requestedOffset {
                if requestedOffset < 0 {
                    // 负 offset 从末尾倒数。`Int.min` 时 `totalLines + offset` 会
                    // 整数溢出 trap，这里用带溢出报告的加法，溢出即钳到文件开头。
                    let sum = totalLines.addingReportingOverflow(requestedOffset)
                    startIndex = sum.overflow ? 0 : max(0, sum.partialValue)
                } else {
                    startIndex = min(max(0, requestedOffset - 1), totalLines)
                }
            } else {
                startIndex = 0
            }

            // limit 已保证为正且不超过上限，endIndex 不会小于 startIndex。
            let endIndex = min(startIndex + limit, totalLines)
            guard startIndex < totalLines else {
                throw ToolExecutionError.executionFailed(
                    toolName: name,
                    reason: "Offset \(requestedOffset ?? 1) is beyond the file's \(totalLines) lines."
                )
            }

            var output: [String] = []
            output.reserveCapacity(endIndex - startIndex)
            var totalChars = 0
            for lineNumber in startIndex..<endIndex {
                let line = lines[lineNumber]
                totalChars += line.count + 1
                if totalChars > 30_000 {
                    output.append("... (output truncated at 30,000 characters)")
                    break
                }
                output.append("\(lineNumber + 1)\t\(line)")
            }

            var result = output.joined(separator: "\n")
            if endIndex < totalLines {
                result += "\n... (showing lines \(startIndex + 1)-\(endIndex) of \(totalLines); use offset/limit to read more)"
            }
            return result
        } catch let error as ToolExecutionError {
            throw error
        } catch {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Error reading file: \(error.localizedDescription)"
            )
        }
    }
}
