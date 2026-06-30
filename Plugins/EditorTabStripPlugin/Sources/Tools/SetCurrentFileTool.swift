import Foundation
import LumiCoreKit
import SuperLogKit

/// 设置当前文件工具
///
/// 基于 StripStore 的 activeTabPath 设置当前活跃文件。
public struct SetCurrentFileTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "set_current_file",
        displayName: LumiPluginLocalization.string("Set Current File", bundle: .module),
        description: LumiPluginLocalization.string("Set the current selected file. Requires a file path. This will open the file in the editor tab strip and switch the UI to display it, making it the active tab visible to the user.", bundle: .module)
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

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "设置当前文件" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let path = arguments["path"]?.stringValue else {
            return "❌ Error: Missing required parameter 'path'"
        }

        // 验证路径是否存在且为文件
        let fm = FileManager.default
        var isDirectory: ObjCBool = false

        guard fm.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return "❌ Error: Path does not exist: \(path)"
        }

        guard !isDirectory.boolValue else {
            return "❌ Error: Path is a directory, not a file: \(path)"
        }

        let projectPath = context.currentProjectPath

        guard let projectPath else {
            return "❌ Error: No project selected. Use `set_current_project` first."
        }

        let fileName = URL(fileURLWithPath: path).lastPathComponent

        let store = StripStore.shared
        store.setCurrentFilePath(path: path, forProject: projectPath)

        NotificationCenter.postCurrentFileDidChange(path: path)

        return """
        ✅ Successfully set current file

        **File Name**: \(fileName)

        **File Path**: \(path)

        The file has been saved and is ready to use.
        """
    }
}
