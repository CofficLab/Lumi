import Foundation
import LumiCoreKit

public struct WriteFileTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "write_file",
        displayName: LumiPluginLocalization.string("Write File", bundle: .module),
        description: LumiPluginLocalization.string("Write UTF-8 text content to a file.", bundle: .module)
    )
    public static let tags: Set<LumiToolTag> = [.fileSystem, .destructive]

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the file")
                ]),
                "content": .object([
                    "type": .string("string"),
                    "description": .string("UTF-8 text content to write")
                ])
            ]),
            "required": .array([.string("path"), .string("content")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        guard let path = arguments["path"]?.stringValue else {
            return "写入文件"
        }
        return "写入 \(URL(fileURLWithPath: path).lastPathComponent)"
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let path = arguments["path"]?.stringValue,
              let content = arguments["content"]?.stringValue
        else {
            throw NSError(domain: "WriteFileTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing path or content"])
        }

        if !context.isPathAllowed(path) {
            throw NSError(domain: "WriteFileTool", code: 403, userInfo: [NSLocalizedDescriptionKey: "Path access denied: \(path)"])
        }

        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return "Wrote \(content.count) characters to \(path)"
    }
}
