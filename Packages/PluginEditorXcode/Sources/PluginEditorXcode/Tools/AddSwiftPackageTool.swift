import Foundation
import AgentToolKit
import XcodeKit
import XcodeProj

/// 向 Xcode 项目添加 Swift Package 的 Agent 工具。
///
/// 支持添加远程 Swift Package（通过 Git URL）和本地 Swift Package（相对路径）。
public struct AddSwiftPackageTool: SuperAgentTool {
    /// 暴露给 Agent 的工具名称。
    public let name = "add_xcode_package"

    /// Package Service 实例
    private let packageService = XcodePackageService()

    /// 返回展示给 Agent 的本地化工具描述。
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "向 Xcode 项目添加 Swift Package 依赖。支持远程 Package（Git URL）和本地 Package（相对路径）。"
        case .english:
            return "Add Swift Package dependencies to an Xcode project. Supports remote packages (Git URL) and local packages (relative path)."
        }
    }

    /// 定义工具接受的 JSON schema。
    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let projectPathDesc: String
        let packageTypeDesc: String
        let repositoryURLDesc: String
        let relativePathDesc: String
        let productNameDesc: String
        let targetNameDesc: String
        let versionKindDesc: String
        let versionDesc: String

        switch language {
        case .chinese:
            projectPathDesc = "Xcode 项目文件路径（.xcodeproj 文件的完整路径）"
            packageTypeDesc = "Package 类型：remote（远程）或 local（本地），默认 remote"
            repositoryURLDesc = "远程 Package 的 Git 仓库 URL（远程 Package 必填）"
            relativePathDesc = "本地 Package 相对于项目根目录的路径（本地 Package 必填）"
            productNameDesc = "要链接的 Package 产品名称"
            targetNameDesc = "要链接 Package 的 Target 名称"
            versionKindDesc = "版本规则类型：upToNextMajor（默认）、upToNextMinor、exact、branch、revision"
            versionDesc = "版本号或分支名/revision 值"

        case .english:
            projectPathDesc = "Xcode project file path (full path to .xcodeproj file)"
            packageTypeDesc = "Package type: 'remote' or 'local', default 'remote'"
            repositoryURLDesc = "Git repository URL for remote package (required for remote packages)"
            relativePathDesc = "Relative path from project root to local package (required for local packages)"
            productNameDesc = "Package product name to link"
            targetNameDesc = "Target name to link the package to"
            versionKindDesc = "Version requirement type: upToNextMajor (default), upToNextMinor, exact, branch, revision"
            versionDesc = "Version number or branch/revision value"
        }

        return [
            "type": "object",
            "properties": [
                "project_path": [
                    "type": "string",
                    "description": projectPathDesc
                ],
                "package_type": [
                    "type": "string",
                    "enum": ["remote", "local"],
                    "description": packageTypeDesc
                ],
                "repository_url": [
                    "type": "string",
                    "description": repositoryURLDesc
                ],
                "relative_path": [
                    "type": "string",
                    "description": relativePathDesc
                ],
                "product_name": [
                    "type": "string",
                    "description": productNameDesc
                ],
                "target_name": [
                    "type": "string",
                    "description": targetNameDesc
                ],
                "version_kind": [
                    "type": "string",
                    "enum": ["upToNextMajor", "upToNextMinor", "exact", "branch", "revision"],
                    "description": versionKindDesc
                ],
                "version": [
                    "type": "string",
                    "description": versionDesc
                ]
            ],
            "required": ["project_path", "product_name", "target_name"]
        ]
    }

    /// 声明该工具为高风险，因为它会修改项目文件。
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    /// 带上下文的风险评估：检查路径是否在沙箱内。
    public func permissionRiskLevel(arguments: [String: ToolArgument], context: ToolExecutionContext?) -> CommandRiskLevel {
        let baseRisk: CommandRiskLevel = .medium

        guard let context, !context.allowedDirectories.isEmpty else {
            return baseRisk
        }

        // 提取项目路径参数
        let projectPath = arguments["project_path"]?.value as? String

        guard let projectPath, context.isPathAllowed(projectPath) else {
            // 路径不在沙箱内，提升风险等级
            return .high
        }

        return baseRisk
    }

    /// 显示描述
    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let productName = arguments["product_name"]?.value as? String ?? "Package"
        let targetName = arguments["target_name"]?.value as? String ?? "target"
        return "添加 Swift Package \(productName) 到 \(targetName)"
    }

    /// 执行添加 Package 操作。
    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        // 验证必填参数
        guard let projectPath = arguments["project_path"]?.value as? String, !projectPath.isEmpty else {
            throw XcodePackageToolError.missingArgument("project_path")
        }

        guard let productName = arguments["product_name"]?.value as? String, !productName.isEmpty else {
            throw XcodePackageToolError.missingArgument("product_name")
        }

        guard let targetName = arguments["target_name"]?.value as? String, !targetName.isEmpty else {
            throw XcodePackageToolError.missingArgument("target_name")
        }

        // 确定 Package 类型
        let packageType = (arguments["package_type"]?.value as? String) ?? "remote"

        try context.checkCancellation()

        if packageType == "remote" {
            // 远程 Package
            guard let repositoryURL = arguments["repository_url"]?.value as? String, !repositoryURL.isEmpty else {
                throw XcodePackageToolError.missingArgument("repository_url")
            }

            // 解析版本规则
            let versionKind = (arguments["version_kind"]?.value as? String) ?? "upToNextMajor"
            let versionValue = arguments["version"]?.value as? String ?? "1.0.0"

            let versionRequirement = parseVersionRequirement(kind: versionKind, version: versionValue)

            try context.checkCancellation()

            return try await packageService.addRemotePackage(
                projectPath: projectPath,
                repositoryURL: repositoryURL,
                productName: productName,
                versionRequirement: versionRequirement,
                targetName: targetName
            )

        } else if packageType == "local" {
            // 本地 Package
            guard let relativePath = arguments["relative_path"]?.value as? String, !relativePath.isEmpty else {
                throw XcodePackageToolError.missingArgument("relative_path")
            }

            try context.checkCancellation()

            return try await packageService.addLocalPackage(
                projectPath: projectPath,
                relativePath: relativePath,
                productName: productName,
                targetName: targetName
            )

        } else {
            throw XcodePackageToolError.invalidPackageType(packageType)
        }
    }

    /// 解析版本规则
    private func parseVersionRequirement(kind: String, version: String) -> XCRemoteSwiftPackageReference.VersionRequirement {
        switch kind.lowercased() {
        case "uptonextmajor":
            return .upToNextMajorVersion(version)
        case "uptonextminor":
            return .upToNextMinorVersion(version)
        case "exact":
            return .exact(version)
        case "branch":
            return .branch(version)
        case "revision":
            return .revision(version)
        default:
            return .upToNextMajorVersion(version)
        }
    }
}

// MARK: - Tool Errors

public enum XcodePackageToolError: LocalizedError {
    case missingArgument(String)
    case invalidPackageType(String)

    public var errorDescription: String? {
        switch self {
        case .missingArgument(let name):
            return "Missing required argument: \(name)"
        case .invalidPackageType(let type):
            return "Invalid package type: \(type). Must be 'remote' or 'local'."
        }
    }
}
