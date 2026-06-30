import Foundation
import LumiCoreKit
import SuperLogKit
import XcodeKit

/// 列出 Xcode 项目中 Swift Package 依赖的 Agent 工具。
public struct ListSwiftPackagesTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "list_xcode_packages",
        displayName: LumiPluginLocalization.string("List Swift Packages", bundle: .module),
        description: LumiPluginLocalization.string("List existing Swift Package dependencies in an Xcode project.", bundle: .module)
    )

    public init() {}

    private let packageService = XcodePackageService()

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Xcode project file path (full path to .xcodeproj file)")
                ])
            ]),
            "required": .array([.string("project_path")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "列出 Swift Package 依赖"
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        guard let projectPath = arguments["project_path"]?.stringValue, !projectPath.isEmpty else {
            throw XcodePackageToolError.missingArgument("project_path")
        }

        try context.checkCancellation()

        return try await packageService.listPackages(projectPath: projectPath)
    }
}
