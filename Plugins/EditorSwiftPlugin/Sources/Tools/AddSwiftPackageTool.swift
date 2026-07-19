import Foundation
import LumiKernel
import SuperLogKit
import XcodeKit
import XcodeProj

/// 向 Xcode 项目添加 Swift Package 的 Agent 工具。
public struct AddSwiftPackageTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📦"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "add_xcode_package",
        displayName: LumiPluginLocalization.string("Add Swift Package", bundle: .module),
        description: LumiPluginLocalization.string("Add Swift Package dependencies to an Xcode project. Supports remote packages (Git URL) and local packages (relative path).", bundle: .module)
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
                ]),
                "package_type": .object([
                    "type": .string("string"),
                    "enum": .array([.string("remote"), .string("local")]),
                    "description": .string("Package type: 'remote' or 'local', default 'remote'")
                ]),
                "repository_url": .object([
                    "type": .string("string"),
                    "description": .string("Git repository URL for remote package (required for remote packages)")
                ]),
                "relative_path": .object([
                    "type": .string("string"),
                    "description": .string("Relative path from project root to local package (required for local packages)")
                ]),
                "product_name": .object([
                    "type": .string("string"),
                    "description": .string("Package product name to link")
                ]),
                "target_name": .object([
                    "type": .string("string"),
                    "description": .string("Target name to link the package to")
                ]),
                "version_kind": .object([
                    "type": .string("string"),
                    "enum": .array([.string("upToNextMajor"), .string("upToNextMinor"), .string("exact"), .string("branch"), .string("revision")]),
                    "description": .string("Version requirement type: upToNextMajor (default), upToNextMinor, exact, branch, revision")
                ]),
                "version": .object([
                    "type": .string("string"),
                    "description": .string("Version number or branch/revision value")
                ])
            ]),
            "required": .array([.string("project_path"), .string("product_name"), .string("target_name")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        let baseRisk: LumiCommandRiskLevel = .medium

        guard let context, !context.allowedDirectories.isEmpty else {
            return baseRisk
        }

        let projectPath = arguments["project_path"]?.stringValue

        guard let projectPath, context.isPathAllowed(projectPath) else {
            return .high
        }

        return baseRisk
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        let productName = arguments["product_name"]?.stringValue ?? "Package"
        let targetName = arguments["target_name"]?.stringValue ?? "target"
        return "添加 Swift Package \(productName) 到 \(targetName)"
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        guard let projectPath = arguments["project_path"]?.stringValue, !projectPath.isEmpty else {
            throw XcodePackageToolError.missingArgument("project_path")
        }

        guard let productName = arguments["product_name"]?.stringValue, !productName.isEmpty else {
            throw XcodePackageToolError.missingArgument("product_name")
        }

        guard let targetName = arguments["target_name"]?.stringValue, !targetName.isEmpty else {
            throw XcodePackageToolError.missingArgument("target_name")
        }

        let packageType = arguments["package_type"]?.stringValue ?? "remote"

        try context.checkCancellation()

        if packageType == "remote" {
            guard let repositoryURL = arguments["repository_url"]?.stringValue, !repositoryURL.isEmpty else {
                throw XcodePackageToolError.missingArgument("repository_url")
            }

            let versionKind = arguments["version_kind"]?.stringValue ?? "upToNextMajor"
            let versionValue = arguments["version"]?.stringValue ?? "1.0.0"

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
            guard let relativePath = arguments["relative_path"]?.stringValue, !relativePath.isEmpty else {
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
