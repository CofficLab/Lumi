import Foundation
import AgentToolKit
import XcodeProjectGen

/// 从 Spec 声明生成 Xcode 项目的 Agent 工具。
///
/// 允许 Agent 通过声明式 API 生成完整的 `.xcodeproj` 文件。
public struct GenerateXcodeProjectTool: SuperAgentTool {
    /// 暴露给 Agent 的工具名称。
    public let name = "generate_xcode_project"

    /// Generator 实例
    private let generator = XcodeProjectGenerator()

    /// 返回展示给 Agent 的本地化工具描述。
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "从声明式配置生成 Xcode 项目（.xcodeproj）。支持 App、Framework、Unit Test 等多种 Target 类型，自动生成 Scheme、Build Settings 和文件引用。"
        case .english:
            return "Generate an Xcode project (.xcodeproj) from a declarative specification. Supports App, Framework, Unit Test targets, automatic Scheme generation, Build Settings, and file references."
        }
    }

    /// 定义工具接受的 JSON schema。
    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let projectRootDesc: String
        let projectNameDesc: String
        let targetsDesc: String
        let schemesDesc: String

        switch language {
        case .chinese:
            projectRootDesc = "项目根目录的绝对路径"
            projectNameDesc = "项目名称（同时也是 .xcodeproj 的文件名）"
            targetsDesc = "Target 配置 JSON 数组"
            schemesDesc = "Scheme 配置 JSON 数组（可选，默认为每个 App Target 自动生成）"
        case .english:
            projectRootDesc = "Absolute path to the project root directory"
            projectNameDesc = "Project name (also used as .xcodeproj filename)"
            targetsDesc = "Target configuration JSON array"
            schemesDesc = "Scheme configuration JSON array (optional, auto-generated for each App target)"
        }

        return [
            "type": "object",
            "properties": [
                "project_root": [
                    "type": "string",
                    "description": projectRootDesc
                ],
                "project_name": [
                    "type": "string",
                    "description": projectNameDesc
                ],
                "targets": [
                    "type": "array",
                    "description": targetsDesc,
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "kind": ["type": "string", "enum": ["app", "framework", "unitTestBundle", "uiTestBundle", "appExtension", "staticLibrary"]],
                            "platform": ["type": "string", "enum": ["iOS", "macOS", "tvOS", "watchOS", "visionOS"], "default": "iOS"],
                            "deployment_target": ["type": "string", "default": "17.0"],
                            "sources": ["type": "array", "items": ["type": "string"]],
                            "resources": ["type": "array", "items": ["type": "string"]],
                            "dependencies": ["type": "array", "items": ["type": "object"]],
                            "settings": ["type": "array", "items": ["type": "object"]],
                            "entitlements_path": ["type": "string"],
                            "info_plist_path": ["type": "string"]
                        ],
                        "required": ["name", "kind"]
                    ]
                ],
                "schemes": [
                    "type": "array",
                    "description": schemesDesc,
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "build_targets": ["type": "array", "items": ["type": "string"]]
                        ],
                        "required": ["name", "build_targets"]
                    ]
                ]
            ],
            "required": ["project_root", "project_name", "targets"]
        ]
    }

    /// 高风险工具：创建新项目文件。
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument], context: ToolExecutionContext?) -> CommandRiskLevel {
        let baseRisk: CommandRiskLevel = .high

        guard let context, !context.allowedDirectories.isEmpty else {
            return baseRisk
        }

        let projectRoot = arguments["project_root"]?.value as? String
        guard let projectRoot, context.isPathAllowed(projectRoot) else {
            return .high
        }

        return .medium
    }

    /// 显示描述
    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let name = arguments["project_name"]?.value as? String ?? "Unknown"
        let targetCount = (arguments["targets"]?.value as? [[String: Any]])?.count ?? 0
        return "生成 Xcode 项目 \(name)（\(targetCount) 个 Target）"
    }

    /// 执行项目生成。
    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        // 验证必填参数
        guard let projectRoot = arguments["project_root"]?.value as? String, !projectRoot.isEmpty else {
            throw GenerateXcodeProjectToolError.missingArgument("project_root")
        }
        guard let projectName = arguments["project_name"]?.value as? String, !projectName.isEmpty else {
            throw GenerateXcodeProjectToolError.missingArgument("project_name")
        }
        guard let targetDicts = arguments["targets"]?.value as? [[String: Any]], !targetDicts.isEmpty else {
            throw GenerateXcodeProjectToolError.missingArgument("targets")
        }

        try context.checkCancellation()

        // 解析 Targets
        let targets = try targetDicts.map { try parseTarget($0) }

        // 解析 Schemes（可选）
        let schemes: [XcodeSchemeSpec] = if let schemeDicts = arguments["schemes"]?.value as? [[String: Any]] {
            try schemeDicts.map { try parseScheme($0) }
        } else {
            []
        }

        // 解析项目级 Build Settings
        let projectSettings: [XcodeBuildSetting] = if let settingsArray = arguments["project_settings"]?.value as? [[String: String]] {
            settingsArray.compactMap { dict -> XcodeBuildSetting? in
                guard let key = dict["key"], let value = dict["value"] else { return nil }
                return .custom(key: key, value: value)
            }
        } else {
            []
        }

        // 构建 Spec
        let spec = XcodeProjectSpec(
            name: projectName,
            settings: projectSettings,
            targets: targets,
            schemes: schemes
        )

        try context.checkCancellation()

        // 生成项目
        let resultPath = try generator.generate(spec: spec, projectRoot: projectRoot)

        return "✅ 成功生成 Xcode 项目：\(resultPath)"
    }

    // MARK: - Parsing Helpers

    /// 从字典解析 Target。
    private func parseTarget(_ dict: [String: Any]) throws -> XcodeTargetSpec {
        guard let name = dict["name"] as? String, !name.isEmpty else {
            throw GenerateXcodeProjectToolError.missingArgument("targets[].name")
        }
        guard let kindStr = dict["kind"] as? String else {
            throw GenerateXcodeProjectToolError.missingArgument("targets[].kind")
        }
        let kind = try parseTargetKind(kindStr)

        let platformStr = dict["platform"] as? String ?? "iOS"
        let platform = XcodePlatform(rawValue: platformStr) ?? .iOS

        let deploymentTarget = dict["deployment_target"] as? String ?? "17.0"
        let sources = dict["sources"] as? [String] ?? []
        let resources = dict["resources"] as? [String] ?? []
        let entitlementsPath = dict["entitlements_path"] as? String
        let infoPlistPath = dict["info_plist_path"] as? String

        // 解析依赖
        let dependencies: [XcodeDependencySpec] = if let depDicts = dict["dependencies"] as? [[String: Any]] {
            try depDicts.map { try parseDependency($0) }
        } else {
            []
        }

        // 解析 Build Settings
        let settings: [XcodeBuildSetting] = if let settingsDicts = dict["settings"] as? [[String: String]] {
            settingsDicts.compactMap { dict -> XcodeBuildSetting? in
                guard let key = dict["key"], let value = dict["value"] else { return nil }
                return parseBuildSetting(key: key, value: value)
            }
        } else {
            []
        }

        return XcodeTargetSpec(
            name: name,
            kind: kind,
            platform: platform,
            deploymentTarget: deploymentTarget,
            sources: sources,
            resources: resources,
            dependencies: dependencies,
            settings: settings,
            entitlementsPath: entitlementsPath,
            infoPlistPath: infoPlistPath
        )
    }

    /// 解析 Target 类型。
    private func parseTargetKind(_ str: String) throws -> XcodeTargetKind {
        switch str.lowercased() {
        case "app": return .app
        case "framework": return .framework
        case "unittestbundle": return .unitTestBundle
        case "uitestbundle": return .uiTestBundle
        case "appextension": return .appExtension
        case "staticlibrary": return .staticLibrary
        default:
            throw GenerateXcodeProjectToolError.invalidTargetKind(str)
        }
    }

    /// 解析依赖声明。
    private func parseDependency(_ dict: [String: Any]) throws -> XcodeDependencySpec {
        if let targetName = dict["target"] as? String {
            return .target(name: targetName)
        }
        if let localPath = dict["local_path"] as? String {
            let product = dict["product"] as? String ?? localPath
            return .local(path: localPath, product: product)
        }
        if let remoteURL = dict["remote_url"] as? String {
            let product = dict["product"] as? String ?? ""
            let versionKind = dict["version_kind"] as? String ?? "upToNextMajor"
            let versionValue = dict["version"] as? String ?? "1.0.0"
            let versionRequirement = parseVersionRequirement(kind: versionKind, version: versionValue)
            return .remote(url: remoteURL, product: product, versionRequirement: versionRequirement)
        }
        if let frameworkName = dict["framework"] as? String {
            return .framework(name: frameworkName)
        }
        throw GenerateXcodeProjectToolError.invalidDependency(dict)
    }

    /// 解析版本要求。
    private func parseVersionRequirement(kind: String, version: String) -> XcodeVersionRequirement {
        switch kind.lowercased() {
        case "uptonextmajor": return .upToNextMajor(version)
        case "uptonextminor": return .upToNextMinor(version)
        case "exact": return .exact(version)
        case "branch": return .branch(version)
        case "revision": return .revision(version)
        default: return .upToNextMajor(version)
        }
    }

    /// 解析 Build Setting。
    private func parseBuildSetting(key: String, value: String) -> XcodeBuildSetting {
        switch key {
        case "PRODUCT_BUNDLE_IDENTIFIER":
            return .bundleIdentifier(value)
        case "DEVELOPMENT_TEAM":
            return .developmentTeam(value)
        case "INFOPLIST_FILE":
            return .infoPlistPath(value)
        case "CODE_SIGN_ENTITLEMENTS":
            return .entitlementsPath(value)
        default:
            return .custom(key: key, value: value)
        }
    }

    /// 解析 Scheme。
    private func parseScheme(_ dict: [String: Any]) throws -> XcodeSchemeSpec {
        guard let name = dict["name"] as? String else {
            throw GenerateXcodeProjectToolError.missingArgument("schemes[].name")
        }
        guard let buildTargets = dict["build_targets"] as? [String] else {
            throw GenerateXcodeProjectToolError.missingArgument("schemes[].build_targets")
        }
        return XcodeSchemeSpec(name: name, buildTargets: buildTargets)
    }
}

// MARK: - Tool Errors

enum GenerateXcodeProjectToolError: LocalizedError {
    case missingArgument(String)
    case invalidTargetKind(String)
    case invalidDependency([String: Any])

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name):
            return "Missing required argument: \(name)"
        case .invalidTargetKind(let kind):
            return "Invalid target kind: \(kind). Must be one of: app, framework, unitTestBundle, uiTestBundle, appExtension, staticLibrary"
        case .invalidDependency(let dict):
            return "Invalid dependency specification: \(dict). Must contain 'target', 'local_path', 'remote_url', or 'framework'"
        }
    }
}
