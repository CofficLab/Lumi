import Foundation
import LumiCoreKit

/// 文件读取工具
///
/// 允许 AI 助手按行读取指定路径的 UTF-8 文本文件，默认每次最多 250 行。
public struct ReadFileTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "read_file",
        displayName: LumiPluginLocalization.string("Read File", bundle: .module),
        description: LumiPluginLocalization.string(
            "Read UTF-8 text from a file by line range. Large files should be read in chunks with offset and limit.",
            bundle: .module
        )
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("The absolute path to the UTF-8 text file to read")
                ]),
                "offset": .object([
                    "type": .string("integer"),
                    "description": .string(
                        "1-based line number to start reading from. Negative values count backwards from the end (e.g. -1 is the last line)."
                    )
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string(
                        "Maximum number of lines to return. Defaults to 250 and is capped at 250 per request."
                    )
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

        if let offset = intArgument(arguments["offset"]) {
            if let limit = intArgument(arguments["limit"]) {
                return "读取 \(fileName)（第 \(offset) 行起，最多 \(limit) 行）"
            }
            return "读取 \(fileName)（从第 \(offset) 行起）"
        }

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
            guard let content = String(data: data, encoding: .utf8) else {
                return "Error: File content is not valid UTF-8 text."
            }

            let request = ReadFileLineReader.Request(
                offset: intArgument(arguments["offset"]),
                limit: intArgument(arguments["limit"])
            )
            let result = ReadFileLineReader.read(content: content, request: request)

            if result.totalLines == 0 {
                return ""
            }

            return result.formattedContent
        } catch {
            return "Error reading file: \(error.localizedDescription)"
        }
    }

    private func intArgument(_ value: LumiJSONValue?) -> Int? {
        switch value {
        case .int(let intValue):
            intValue
        case .double(let doubleValue):
            Int(doubleValue)
        default:
            nil
        }
    }
}
