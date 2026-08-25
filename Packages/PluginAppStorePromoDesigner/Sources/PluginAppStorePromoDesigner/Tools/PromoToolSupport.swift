import KitAgentTool
import KitAppStorePromo
import Foundation

/// 共享给所有宣传图工具的辅助逻辑（KernelCore 体系）。
///
/// 由旧版 `Plugins/AppStorePromoDesignerPlugin/Sources/Tools/PromoToolSupport.swift`
/// 迁移而来，差异：
/// - 参数类型 `[String: LumiJSONValue]` → `[String: ToolArgument]`
/// - 移除 `kernel: KernelLumi` 上下文，scope / 项目路径直接读 `PromoDesignerRuntime`
/// - 语言从 `kernel.language` → `LanguagePreference.current`（跟随系统/宿主注入）
enum PromoToolSupport {
    /// 当前语言偏好（跟随系统 locale）。
    static var language: LanguagePreference { .current }

    static let store = AppStorePromoDocumentStore()

    // MARK: - Scope & storage resolution

    /// 当前已打开项目的路径（来自 Runtime 缓存）。
    static func currentProjectPath() async -> String? {
        await MainActor.run {
            PromoDesignerRuntime.currentProjectPath?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
        }
    }

    /// 解析工具入参中的 scope：未指定时按是否有打开项目自动选择 project / app。
    static func resolveScope(_ arguments: [String: ToolArgument]) async throws -> PromoScope {
        if let raw = string(arguments, "scope")?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !raw.isEmpty {
            guard let scope = PromoScope(rawValue: raw) else {
                throw ToolArgumentError.invalid("scope")
            }
            return scope
        }
        let hasProject = await (currentProjectPath() != nil)
        return await MainActor.run { PromoDesignerRuntime.defaultScope(hasOpenProject: hasProject) }
    }

    /// 当前 scope 的存储路径。无路径时抛 invalidStoragePath。
    static func storagePath(for scope: PromoScope) async throws -> String {
        try await MainActor.run {
            let path: String
            switch scope {
            case .project: path = WorkspaceStore.shared.projectStoragePath
            case .app: path = WorkspaceStore.shared.appStoragePath
            }
            guard !path.isEmpty else { throw AppStorePromoStoreError.invalidStoragePath }
            return path
        }
    }

    static func required(_ key: String, _ arguments: [String: ToolArgument]) throws -> String {
        guard let value = string(arguments, key)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw ToolArgumentError.missing(key)
        }
        return value
    }

    static func notify(scope: PromoScope, taskID: String? = nil, imageID: String? = nil) async {
        await MainActor.run { WorkspaceStore.shared.reload(scope: scope, selectTask: taskID, image: imageID) }
    }

    static func taskSummary(_ task: AppStorePromoTask, scope: PromoScope) -> String {
        let displays = AppStorePromoDisplaySpec.presets(for: task.deviceFamily)
            .map { "\($0.displayType)=\($0.width)x\($0.height)" }.joined(separator: ", ")
        let images = task.images.sorted(by: { $0.order < $1.order })
            .map { "\($0.order + 1):\($0.id)" }.joined(separator: ", ")
        return "scope=\(scope.rawValue) taskId=\(task.id) title=\(task.title) appName=\(task.appName) family=\(task.deviceFamily.rawValue) locale=\(task.localeIdentifier) displayTypes=[\(displays)] images=[\(images)]"
    }

    static func baseProperties(includeImage: Bool = false, includeScope: Bool = true) -> [String: Any] {
        var result: [String: Any] = [:]
        if includeScope {
            result["scope"] = [
                "type": "string",
                "enum": PromoScope.allCases.map(\.rawValue),
                "description": "Storage scope: 'project' (current project .lumi folder) or 'app' (application data directory). Defaults to 'project' when a project is open, else 'app'.",
            ]
        }
        result["taskId"] = ["type": "string", "description": "Promotional artwork task slug."]
        if includeImage {
            result["imageId"] = ["type": "string", "description": "Promotional image slug within the task."]
            result["localeIdentifier"] = [
                "type": "string",
                "description": "Optional image language version, such as en-US, zh-Hans, or ja. Defaults to the image's primary language."
            ]
        }
        return result
    }

    // MARK: - Argument accessors（ToolArgument 版）

    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        arguments[key]?.value as? String
    }

    static func bool(_ arguments: [String: ToolArgument], _ key: String, default defaultValue: Bool = false) -> Bool {
        guard let value = arguments[key]?.value else { return defaultValue }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        return defaultValue
    }

    static func stringArray(_ arguments: [String: ToolArgument], _ key: String) -> [String]? {
        guard let value = arguments[key]?.value as? [Any] else { return nil }
        let strings = value.compactMap { $0 as? String }
        return strings.isEmpty ? nil : strings
    }

    // MARK: - Localization helpers

    static func localized(_ language: LanguagePreference, en: String, zh: String) -> String {
        switch language {
        case .chinese: zh
        case .english: en
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

    static func description(_ language: LanguagePreference, en: String, zh: String) -> String {
        localized(language, en: en, zh: zh)
    }

    static func localizedErrorDescription(_ description: String) -> String {
        if description == "No App Store promotional artwork task is selected." {
            return "未选中 App Store 促销图任务。"
        }
        if let suffix = description.dropPrefix("Promotional artwork task not found: ") {
            return "找不到促销图任务：\(suffix)"
        }
        if let suffix = description.dropPrefix("Promotional image not found: ") {
            return "找不到促销图：\(suffix)"
        }
        if let suffix = description.dropPrefix("Image file not found: ") {
            return "找不到图片文件：\(suffix)"
        }
        if let suffix = description.dropPrefix("Unsupported image file: ") {
            return "不支持的图片文件：\(suffix)"
        }
        if description == "Missing required argument: taskId" {
            return "缺少必填参数：taskId"
        }
        if description == "Missing required argument: imageId" {
            return "缺少必填参数：imageId"
        }
        return description
    }

    enum ToolArgumentError: LocalizedError {
        case missing(String)
        case invalid(String)
        var errorDescription: String? {
            switch self {
            case .missing(let key): "Missing required argument: \(key)"
            case .invalid(let key): "Invalid argument: \(key)"
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func dropPrefix(_ prefix: String) -> Substring? {
        guard hasPrefix(prefix) else { return nil }
        return dropFirst(prefix.count)
    }
}
