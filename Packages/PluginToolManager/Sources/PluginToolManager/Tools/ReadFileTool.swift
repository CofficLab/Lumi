import KitAgentTool
import Foundation

/// 按行读取文件，支持 offset/limit 与截断。
public struct ReadFileTool: SuperAgentTool, @unchecked Sendable {
    public let name = "read_file"

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
                "limit": ["type": "integer", "description": "Maximum number of lines to return. Defaults to 250 and is capped at 250 per request."],
            ],
            "required": ["path"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let path = arguments.stringValue("path") else { return "读取文件" }
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        if let offset = arguments.intValue("offset") {
            if let limit = arguments.intValue("limit") {
                return "读取 \(fileName)（第 \(offset) 行起，最多 \(limit) 行）"
            }
            return "读取 \(fileName)（从第 \(offset) 行起）"
        }
        return "读取 \(fileName)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let path = arguments.stringValue("path") else {
            throw NSError(domain: "ReadFileTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"])
        }

        let url = WorkspacePathResolver.resolve(
            path: path,
            workspaceRoot: await workspaceRootProvider()
        )
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard fileSize <= Self.maxWholeFileBytes else {
                return "Error: File is too large (\(fileSize) bytes; maximum is \(Self.maxWholeFileBytes) bytes). Read it in chunks."
            }

            let rawText = try String(contentsOf: url, encoding: .utf8)
            let lines = rawText.components(separatedBy: "\n")
            let totalLines = lines.count

            let requestedOffset = arguments.intValue("offset")
            let requestedLimit = arguments.intValue("limit")

            let (startIndex, limit): (Int, Int)
            if let requestedOffset {
                if requestedOffset < 0 {
                    startIndex = max(0, totalLines + requestedOffset)
                } else {
                    startIndex = min(max(0, requestedOffset - 1), totalLines)
                }
                limit = min(requestedLimit ?? Self.defaultLineLimit, Self.maxLineLimit)
            } else {
                startIndex = 0
                limit = min(requestedLimit ?? Self.defaultLineLimit, Self.maxLineLimit)
            }

            let endIndex = min(startIndex + limit, totalLines)
            guard startIndex < totalLines else {
                return "Error: Offset \(requestedOffset ?? 1) is beyond the file's \(totalLines) lines."
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
        } catch {
            return "Error reading file: \(error.localizedDescription)"
        }
    }
}
