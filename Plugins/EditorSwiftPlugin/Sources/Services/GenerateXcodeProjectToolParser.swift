import Foundation
import XcodeProjectGen

enum GenerateXcodeProjectToolParser {
    // MARK: - Parsing Helpers

    /// 从字典解析 Target。
    static func parseTarget(_ dict: [String: Any]) throws -> XcodeTargetSpec {
        guard let name = dict["name"] as? String, !name.isEmpty else {
            throw GenerateXcodeProjectToolError.missingArgument("targets[].name")
        }
        guard let kindStr = dict["kind"] as? String else {
            throw GenerateXcodeProjectToolError.missingArgument("targets[].kind")
        }
        let kind = try Self.parseTargetKind(kindStr)

        let platformStr = dict["platform"] as? String ?? "iOS"
        let platform = XcodePlatform(rawValue: platformStr) ?? .iOS

        let deploymentTarget = dict["deployment_target"] as? String ?? "17.0"
        let sources = dict["sources"] as? [String] ?? []
        let resources = dict["resources"] as? [String] ?? []
        let entitlementsPath = dict["entitlements_path"] as? String
        let infoPlistPath = dict["info_plist_path"] as? String

        // 解析依赖
        let dependencies: [XcodeDependencySpec] = if let depDicts = dict["dependencies"] as? [[String: Any]] {
            try depDicts.map { try Self.parseDependency($0) }
        } else {
            []
        }

        // 解析 Build Settings
        let settings: [XcodeBuildSetting] = if let settingsDicts = dict["settings"] as? [[String: String]] {
            settingsDicts.compactMap { dict -> XcodeBuildSetting? in
                guard let key = dict["key"], let value = dict["value"] else { return nil }
                return Self.parseBuildSetting(key: key, value: value)
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
    static func parseTargetKind(_ str: String) throws -> XcodeTargetKind {
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
    static func parseDependency(_ dict: [String: Any]) throws -> XcodeDependencySpec {
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
            let versionRequirement = Self.parseVersionRequirement(kind: versionKind, version: versionValue)
            return .remote(url: remoteURL, product: product, versionRequirement: versionRequirement)
        }
        if let frameworkName = dict["framework"] as? String {
            return .framework(name: frameworkName)
        }
        throw GenerateXcodeProjectToolError.invalidDependency(dict)
    }

    /// 解析版本要求。
    static func parseVersionRequirement(kind: String, version: String) -> XcodeVersionRequirement {
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
    static func parseBuildSetting(key: String, value: String) -> XcodeBuildSetting {
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
    static func parseScheme(_ dict: [String: Any]) throws -> XcodeSchemeSpec {
        guard let name = dict["name"] as? String else {
            throw GenerateXcodeProjectToolError.missingArgument("schemes[].name")
        }
        guard let buildTargets = dict["build_targets"] as? [String] else {
            throw GenerateXcodeProjectToolError.missingArgument("schemes[].build_targets")
        }
        return XcodeSchemeSpec(name: name, buildTargets: buildTargets)
    }
}

