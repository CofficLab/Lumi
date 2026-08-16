import AgentToolKit
import Foundation
import ResumeKit

/// Agent 工具的共享支持逻辑（KernelCore 体系）。
///
/// 由旧版 `Plugins/ResumeDesignerPlugin/Sources/Tools/ResumeToolSupport.swift`
/// 迁移而来，差异：
/// - 参数类型 `[String: LumiJSONValue]` → `[String: ToolArgument]`
/// - 语言从 `kernel.language` → `LanguagePreference.current`（跟随系统/宿主注入）
/// - 存储路径直接读 `WorkspaceStore.shared.appStoragePath`，不再依赖 `KernelLumi`
/// - 简历文档仅存储在应用数据目录（app 作用域），不支持项目内存储
enum ResumeToolSupport {
    /// 当前语言偏好（跟随系统 locale）。
    static var language: LanguagePreference { .current }

    static let store = ResumeDocumentStore()

    // MARK: - Storage & argument helpers

    /// 当前 app 存储路径（应用数据目录）。无路径时抛 invalidStoragePath。
    static func storagePath() async throws -> String {
        try await MainActor.run {
            let path = WorkspaceStore.shared.appStoragePath
            guard !path.isEmpty else { throw ResumeStoreError.invalidStoragePath }
            return path
        }
    }

    static func required(_ key: String, _ arguments: [String: ToolArgument]) throws -> String {
        guard let value = string(arguments, key)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw ResumeToolArgumentError.missing(key)
        }
        return value
    }

    static func notify(resumeID: String? = nil) async {
        await MainActor.run { WorkspaceStore.shared.reload(selectResume: resumeID) }
    }

    static func resumeSummary(_ document: ResumeDocument) -> String {
        "resumeId=\(document.id) title=\(document.title) paper=\(document.paper.rawValue) template=\(document.template.rawValue) updatedAt=\(document.updatedAt.timeIntervalSince1970)"
    }

    static func baseProperties() -> [String: Any] {
        [
            "resumeId": ["type": "string", "description": "Resume slug."],
        ]
    }

    enum ResumeToolArgumentError: LocalizedError {
        case missing(String)
        case invalid(String)
        var errorDescription: String? {
            switch self {
            case .missing(let key): "Missing required argument: \(key)"
            case .invalid(let key): "Invalid argument: \(key)"
            }
        }
    }

    // MARK: - Localization helpers

    static func localized(_ language: LanguagePreference, en: String, zh: String) -> String {
        switch language {
        case .chinese:
            zh
        case .english:
            en
        }
    }

    static func error(_ error: Error, language: LanguagePreference) -> String {
        localized(
            language,
            en: "Error: \(error.localizedDescription)",
            zh: "错误：\(localizedErrorDescription(error.localizedDescription))"
        )
    }

    static func missingParameter(_ name: String, language: LanguagePreference) -> String {
        localized(
            language,
            en: "Error: Missing required '\(name)' parameter.",
            zh: "错误：缺少必填参数 '\(name)'。"
        )
    }

    static func localizedErrorDescription(_ description: String) -> String {
        if description == "Plugin storage path is missing or invalid." {
            return "插件存储路径缺失或无效。"
        }
        if let suffix = description.dropPrefix("Resume not found at ") {
            return "找不到简历：\(suffix)"
        }
        if let suffix = description.dropPrefix("Invalid slug: ") {
            return "无效的 slug：\(suffix)"
        }
        if let suffix = description.dropPrefix("HTML validation failed: ") {
            return "HTML 校验失败：\(suffix)"
        }
        if let suffix = description.dropPrefix("Patch text was not found: ") {
            return "找不到要替换的文本：\(suffix)"
        }
        if let suffix = description.dropPrefix("Patch text must occur exactly once: ") {
            return "要替换的文本必须只出现一次：\(suffix)"
        }
        if description == "HTML contains no .resume-page elements." {
            return "HTML 中没有任何 .resume-page 元素。"
        }
        if description.hasPrefix("Page "), description.hasSuffix(" the paper preset requires") {
            return description
        }
        return description
    }

    // MARK: - Argument accessors（ToolArgument 版）

    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        arguments[key]?.value as? String
    }

    static func double(_ arguments: [String: ToolArgument], _ key: String, default defaultValue: Double) -> Double {
        optionalDouble(arguments, key) ?? defaultValue
    }

    static func optionalDouble(_ arguments: [String: ToolArgument], _ key: String) -> Double? {
        guard let value = arguments[key]?.value else { return nil }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    static func bool(_ arguments: [String: ToolArgument], _ key: String, default defaultValue: Bool) -> Bool {
        guard let value = arguments[key]?.value else { return defaultValue }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        return defaultValue
    }

    static func int(_ arguments: [String: ToolArgument], _ key: String) -> Int? {
        guard let value = arguments[key]?.value else { return nil }
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    static func array(_ arguments: [String: ToolArgument], _ key: String) -> [Any] {
        arguments[key]?.value as? [Any] ?? []
    }
}

private extension String {
    func dropPrefix(_ prefix: String) -> Substring? {
        guard hasPrefix(prefix) else { return nil }
        return dropFirst(prefix.count)
    }
}
