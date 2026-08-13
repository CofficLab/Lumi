import Foundation
import KernelLumi

public struct GetCurrentFileTool: LumiAgentTool {
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "get_current_file",
        displayName: "Get Current File",
        description: "Get the current file path for the active project."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Get current file"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let currentFileURL = await MainActor.run {
            kernel.project?.currentFileURL
        }

        guard let currentFileURL else {
            return """
            ## Current File Status

            **Status**: No file selected
            """
        }

        return """
        ## Current File Info

        **File Name**: \(currentFileURL.lastPathComponent)

        **File Path**: \(currentFileURL.path)
        """
    }
}
