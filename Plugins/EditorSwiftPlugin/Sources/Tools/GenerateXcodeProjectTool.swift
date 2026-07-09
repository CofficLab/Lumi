import Foundation
import LumiCoreKit
import SuperLogKit
import XcodeProjectGen

/// 从 Spec 声明生成 Xcode 项目的 Agent 工具。
public struct GenerateXcodeProjectTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🛠️"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "generate_xcode_project",
        displayName: LumiPluginLocalization.string("Generate Xcode Project", bundle: .module),
        description: LumiPluginLocalization.string("Generate an Xcode project (.xcodeproj) from a declarative specification. Supports App, Framework, Unit Test targets, automatic Scheme generation, Build Settings, and file references.", bundle: .module)
    )

    public init() {}

    private let generator = XcodeProjectGenerator()

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "project_root": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the project root directory")
                ]),
                "project_name": .object([
                    "type": .string("string"),
                    "description": .string("Project name (also used as .xcodeproj filename)")
                ]),
                "targets": .object([
                    "type": .string("array"),
                    "description": .string("Target configuration JSON array"),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "name": .object(["type": .string("string")]),
                            "kind": .object([
                                "type": .string("string"),
                                "enum": .array([.string("app"), .string("framework"), .string("unitTestBundle"), .string("uiTestBundle"), .string("appExtension"), .string("staticLibrary")])
                            ]),
                            "platform": .object([
                                "type": .string("string"),
                                "enum": .array([.string("iOS"), .string("macOS"), .string("tvOS"), .string("watchOS"), .string("visionOS")])
                            ]),
                            "deployment_target": .object(["type": .string("string")]),
                            "sources": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
                            "resources": .object(["type": .string("array"), "items": .object(["type": .string("string")])])
                        ]),
                        "required": .array([.string("name"), .string("kind")])
                    ])
                ]),
                "schemes": .object([
                    "type": .string("array"),
                    "description": .string("Scheme configuration JSON array (optional, auto-generated for each App target)"),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "name": .object(["type": .string("string")]),
                            "build_targets": .object(["type": .string("array"), "items": .object(["type": .string("string")])])
                        ]),
                        "required": .array([.string("name"), .string("build_targets")])
                    ])
                ])
            ]),
            "required": .array([.string("project_root"), .string("project_name"), .string("targets")])
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        let baseRisk: LumiCommandRiskLevel = .high

        guard let context, !context.allowedDirectories.isEmpty else {
            return baseRisk
        }

        let projectRoot = arguments["project_root"]?.stringValue
        guard let projectRoot, context.isPathAllowed(projectRoot) else {
            return .high
        }

        return .medium
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        let name = arguments["project_name"]?.stringValue ?? "Unknown"
        let targetCount: Int
        if case .array(let targets) = arguments["targets"] {
            targetCount = targets.count
        } else if let any = arguments["targets"]?.anyValue as? [[String: Any]] {
            targetCount = any.count
        } else {
            targetCount = 0
        }
        return "生成 Xcode 项目 \(name)（\(targetCount) 个 Target）"
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()

        guard let projectRoot = arguments["project_root"]?.stringValue, !projectRoot.isEmpty else {
            throw GenerateXcodeProjectToolError.missingArgument("project_root")
        }
        guard let projectName = arguments["project_name"]?.stringValue, !projectName.isEmpty else {
            throw GenerateXcodeProjectToolError.missingArgument("project_name")
        }
        
        let targetDicts: [[String: Any]]
        if case .array(let arr) = arguments["targets"] {
            targetDicts = arr.compactMap { $0.anyValue as? [String: Any] }
        } else if let any = arguments["targets"]?.anyValue as? [[String: Any]] {
            targetDicts = any
        } else {
            throw GenerateXcodeProjectToolError.missingArgument("targets")
        }
        
        guard !targetDicts.isEmpty else {
            throw GenerateXcodeProjectToolError.missingArgument("targets")
        }

        try context.checkCancellation()

        let targets = try targetDicts.map { try parseTarget($0) }

        let schemes: [XcodeSchemeSpec]
        if case .array(let schemeArr) = arguments["schemes"] {
            schemes = try schemeArr.compactMap { $0.anyValue as? [String: Any] }.map { try parseScheme($0) }
        } else if let schemeAny = arguments["schemes"]?.anyValue as? [[String: Any]] {
            schemes = try schemeAny.map { try parseScheme($0) }
        } else {
            schemes = []
        }

        let projectSettings: [XcodeBuildSetting]
        if case .array(let settingsArr) = arguments["project_settings"] {
            projectSettings = settingsArr.compactMap { dict -> XcodeBuildSetting? in
                guard let dict = dict.anyValue as? [String: String],
                      let key = dict["key"], let value = dict["value"] else { return nil }
                return .custom(key: key, value: value)
            }
        } else {
            projectSettings = []
        }

        let spec = XcodeProjectSpec(
            name: projectName,
            settings: projectSettings,
            targets: targets,
            schemes: schemes
        )

        try context.checkCancellation()

        let resultPath = try generator.generate(spec: spec, projectRoot: projectRoot)

        return "✅ 成功生成 Xcode 项目：\(resultPath)"
    }

    private func parseTarget(_ dict: [String: Any]) throws -> XcodeTargetSpec {
        try GenerateXcodeProjectToolParser.parseTarget(dict)
    }

    private func parseTargetKind(_ str: String) throws -> XcodeTargetKind {
        try GenerateXcodeProjectToolParser.parseTargetKind(str)
    }

    private func parseDependency(_ dict: [String: Any]) throws -> XcodeDependencySpec {
        try GenerateXcodeProjectToolParser.parseDependency(dict)
    }

    private func parseVersionRequirement(kind: String, version: String) -> XcodeVersionRequirement {
        GenerateXcodeProjectToolParser.parseVersionRequirement(kind: kind, version: version)
    }

    private func parseBuildSetting(key: String, value: String) -> XcodeBuildSetting {
        GenerateXcodeProjectToolParser.parseBuildSetting(key: key, value: value)
    }

    private func parseScheme(_ dict: [String: Any]) throws -> XcodeSchemeSpec {
        try GenerateXcodeProjectToolParser.parseScheme(dict)
    }
}

public enum GenerateXcodeProjectToolError: LocalizedError {
    case missingArgument(String)
    case invalidTargetKind(String)
    case invalidDependency([String: Any])

    public var errorDescription: String? {
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
