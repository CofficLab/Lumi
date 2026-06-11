import Foundation
import LumiCoreKit

/// 文件读取工具
///
/// 允许 AI 助手读取指定路径的文件内容。
public struct ReadFileTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "read_file",
        displayName: String(localized: "Read File", bundle: .module),
        description: String(localized: "Read UTF-8 text contents from a file at the given path.", bundle: .module)
    )

    private let maxBytes = 50 * 1024

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("The absolute path to the UTF-8 text file to read")
                ])
            ]),
            "required": .array([.string("path")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        guard let path = arguments["path"]?.stringValue else { return "读取文件" }
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        return "读取 \(fileName)"
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let path = arguments["path"]?.stringValue else {
            throw NSError(
                domain: "ReadFileTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"]
            )
        }

        if !context.isPathAllowed(path) {
            throw NSError(
                domain: "ReadFileTool",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Path access denied: \(path)\n\n此路径不在允许的文件操作范围内。"]
            )
        }

        do {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            let data = try Data(contentsOf: url)
            let truncated = data.count > maxBytes
            let readableData = truncated ? data.prefix(maxBytes) : data[...]

            guard let content = String(data: Data(readableData), encoding: .utf8) else {
                return "Error: File content is not valid UTF-8 text."
            }

            return truncated ? "\(content)\n... (File truncated due to size limit)" : content
        } catch {
            return "Error reading file: \(error.localizedDescription)"
        }
    }
}
