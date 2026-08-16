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
        // Phase 3:当前文件唯一事实源是 Editor（kernel.editorV2），不再读 Project 状态。
        let currentFileURL = await MainActor.run {
            kernel.editorV2?.documents.activeDocument?.uri
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
