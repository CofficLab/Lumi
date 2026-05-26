import Foundation
import AgentToolKit
import XcodeKit

/// 列出 Xcode 项目中 Swift Package 依赖的 Agent 工具。
struct ListSwiftPackagesTool: SuperAgentTool {
    /// 暴露给 Agent 的工具名称。
    let name = "list_xcode_packages"

    /// Package Service 实例
    private let packageService = XcodePackageService()

    /// 返回展示给 Agent 的本地化工具描述。
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "列出 Xcode 项目中已有的 Swift Package 依赖。"
        case .english:
            return "List existing Swift Package dependencies in an Xcode project."
        }
    }

    /// 定义工具接受的 JSON schema。
    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let projectPathDesc: String

        switch language {
        case .chinese:
            projectPathDesc = "Xcode 项目文件路径（.xcodeproj 文件的完整路径）"
        case .english:
            projectPathDesc = "Xcode project file path (full path to .xcodeproj file)"
        }

        return [
            "type": "object",
            "properties": [
                "project_path": [
                    "type": "string",
                    "description": projectPathDesc
                ]
            ],
            "required": ["project_path"]
        ]
    }

    /// 声明该工具为低风险，因为它只读取项目文件。
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    /// 显示描述
    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "列出 Swift Package 依赖"
    }

    /// 执行列出 Package 操作。
    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        // 验证必填参数
        guard let projectPath = arguments["project_path"]?.value as? String, !projectPath.isEmpty else {
            throw XcodePackageToolError.missingArgument("project_path")
        }

        try context.checkCancellation()

        return try await packageService.listPackages(projectPath: projectPath)
    }
}