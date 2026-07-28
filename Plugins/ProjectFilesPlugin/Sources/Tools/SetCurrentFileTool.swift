import Foundation
import LumiKernel

public struct SetCurrentFileTool: LumiAgentTool {
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "set_current_file",
        displayName: "Set Current File",
        description: "Set the current file for the active project."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the file")
                ])
            ]),
            "required": .array([.string("path")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Set current file"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard let path = arguments["path"]?.stringValue else {
            return "❌ Error: Missing required parameter 'path'"
        }

        let fm = FileManager.default
        var isDirectory: ObjCBool = false

        guard fm.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return "❌ Error: Path does not exist: \(path)"
        }

        guard !isDirectory.boolValue else {
            return "❌ Error: Path is a directory, not a file: \(path)"
        }

        let hasProject = await MainActor.run {
            kernel.project != nil
        }

        guard hasProject else {
            return "❌ Error: No project selected."
        }

        let fileURL = URL(fileURLWithPath: path)
        await MainActor.run {
            kernel.project?.updateCurrentFile(fileURL)
        }

        return """
        ✅ Successfully set current file

        **File Name**: \(fileURL.lastPathComponent)

        **File Path**: \(fileURL.path)
        """
    }
}
