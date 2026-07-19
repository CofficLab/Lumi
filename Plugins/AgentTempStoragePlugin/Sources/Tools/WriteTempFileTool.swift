import Foundation
import LumiKernel

struct WriteTempFileTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "write_temp_file",
        displayName: PluginAgentTempStorageLocalization.string("Write Temp File"),
        description: PluginAgentTempStorageLocalization.string(
            "Write UTF-8 text to the agent temp storage directory. Files are auto-deleted after the retention period (default 7 days)."
        )
    )

    init() {}

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "filename": .object([
                    "type": .string("string"),
                    "description": .string("Relative filename within temp storage, e.g. \"report.md\" or \"exports/data.json\"")
                ]),
                "content": .object([
                    "type": .string("string"),
                    "description": .string("UTF-8 text content to write")
                ])
            ]),
            "required": .array([.string("filename"), .string("content")])
        ])
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        guard let filename = arguments["filename"]?.stringValue else {
            return Self.info.displayName
        }
        return "Write temp file \(filename)"
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let filename = arguments["filename"]?.stringValue,
              let content = arguments["content"]?.stringValue
        else {
            throw NSError(
                domain: "WriteTempFileTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing filename or content"]
            )
        }

        let path = try await TempFileStorageService.shared.write(filename: filename, content: content)
        let directory = await TempFileStorageService.shared.storageDirectoryPath
        return "Wrote \(content.count) characters to \(path)\nStorage directory: \(directory)"
    }
}
