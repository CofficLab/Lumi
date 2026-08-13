import Foundation
import KernelLumi
import LocalizationKit

struct ReadTempFileTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "read_temp_file",
        displayName: LumiPluginLocalization.string("Read Temp File", bundle: .module),
        description: LumiPluginLocalization.string(
            "Read UTF-8 text from a file in the agent temp storage directory.",
            bundle: .module
        )
    )

    init() {}

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "filename": .object([
                    "type": .string("string"),
                    "description": .string("Relative filename within temp storage")
                ])
            ]),
            "required": .array([.string("filename")])
        ])
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        guard let filename = arguments["filename"]?.stringValue else {
            return Self.info.displayName
        }
        return "Read temp file \(filename)"
    }

    func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        guard let filename = arguments["filename"]?.stringValue else {
            throw NSError(
                domain: "ReadTempFileTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing filename"]
            )
        }

        return try await TempFileStorageService.shared.read(filename: filename)
    }
}
