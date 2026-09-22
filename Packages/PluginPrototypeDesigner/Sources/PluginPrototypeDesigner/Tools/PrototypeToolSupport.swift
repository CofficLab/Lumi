import Foundation
import KitAgentTool
import KitPrototype

/// 共享给所有原型工具的辅助逻辑。
enum PrototypeToolSupport {
    /// 当前语言偏好（跟随系统 locale）。
    static var language: LanguagePreference { .current }

    static let store = PrototypeDocumentStore()

    // MARK: - 项目存储解析

    /// 当前已打开项目的路径（来自 Runtime 缓存）。
    static func currentProjectPath() async -> String? {
        await MainActor.run {
            if case .conversation(let projectPath) = PrototypeConversationProjectScope.binding {
                return normalizedProjectPath(projectPath)
            }
            return PrototypeDesignerRuntime.currentProjectPath
                .flatMap { normalizedProjectPath($0) }
        }
    }

    /// 当前调用所属项目的存储路径。Agent 工具按会话项目解析；直接 UI 调用
    /// 才回退到当前打开项目。无项目时抛 invalidStoragePath。
    static func storagePath() async throws -> String {
        try await MainActor.run {
            if case .conversation(let projectPath) = PrototypeConversationProjectScope.binding {
                guard let directory = PrototypeDesignerRuntime.prototypeStorageDirectory(forProjectPath: projectPath) else {
                    throw PrototypeStoreError.invalidStoragePath
                }
                return directory.path
            }
            let path = WorkspaceStore.shared.projectStoragePath
            guard !path.isEmpty else { throw PrototypeStoreError.invalidStoragePath }
            return path
        }
    }

    private static func normalizedProjectPath(_ path: String?) -> String? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
    }

    static func required(_ key: String, _ arguments: [String: ToolArgument]) throws -> String {
        guard let value = string(arguments, key)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw ToolArgumentError.missing(key)
        }
        return value
    }

    static func notify(projectID: String? = nil, screenID: String? = nil) async {
        await MainActor.run {
            if case .conversation(let projectPath) = PrototypeConversationProjectScope.binding {
                guard normalizedProjectPath(projectPath)
                    == normalizedProjectPath(WorkspaceStore.shared.currentProjectPath) else {
                    return
                }
            }
            WorkspaceStore.shared.reload(selectProject: projectID, screen: screenID)
        }
    }

    // MARK: - 摘要

    /// 项目摘要：元数据 + 设备尺寸 + 屏幕清单。让 LLM 不读 HTML 就知道项目结构。
    static func projectSummary(_ project: PrototypeProject) -> String {
        let device = project.device
        var lines: [String] = [
            "projectId=\(project.id) title=\(project.title) style=\(project.style.rawValue)",
            "device=\(device.kind.rawValue) logical=\(Int(device.width))x\(Int(device.height)) scale=\(device.scale)x export=\(device.pixelWidth)x\(device.pixelHeight)",
            "screenCount=\(project.screens.count) startScreen=\(project.resolvedStartScreen?.id ?? "none")",
        ]
        if project.sortedScreens.isEmpty {
            lines.append("screens=[]")
        } else {
            lines.append("screens:")
            for screen in project.sortedScreens {
                lines.append("  \(screenSummary(screen))")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// 单屏摘要：顺序、标题、跳转拓扑。
    static func screenSummary(_ screen: PrototypeScreen) -> String {
        let order = screen.order + 1
        let links = screen.hotspots.isEmpty
            ? "links=[]"
            : "links=[" + screen.hotspots.map { hotspot in
                if let label = hotspot.label {
                    "\(hotspot.targetScreenID)(\(label))"
                } else {
                    hotspot.targetScreenID
                }
            }.joined(separator: ", ") + "]"
        return "#\(order) id=\(screen.id) title=\(screen.title) \(links)"
    }

    /// 把项目的完整跳转图渲染成便于 LLM 阅读的文本。
    static func flowSummary(_ project: PrototypeProject) -> String {
        let screens = project.sortedScreens
        guard !screens.isEmpty else { return "flow: (no screens)" }
        var lines = ["flow (start=\(project.resolvedStartScreen?.id ?? "none")):"]
        for screen in screens {
            if screen.hotspots.isEmpty {
                lines.append("  \(screen.id) -> (nothing)")
            } else {
                let targets = screen.hotspots.map { hotspot -> String in
                    let known = project.screen(id: hotspot.targetScreenID) != nil
                    return known ? hotspot.targetScreenID : "\(hotspot.targetScreenID)[MISSING]"
                }
                lines.append("  \(screen.id) -> \(targets.joined(separator: ", "))")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Schema 属性

    static func baseProperties(includeScreen: Bool = false) -> [String: Any] {
        var result: [String: Any] = [:]
        result["projectId"] = ["type": "string", "description": "Prototype project slug."]
        if includeScreen {
            result["screenId"] = ["type": "string", "description": "Screen slug within the project."]
        }
        return result
    }

    /// 设备参数 schema 片段，供 create/update 设备类工具复用。
    static var deviceProperties: [String: Any] {
        [
            "deviceKind": [
                "type": "string",
                "enum": PrototypeDeviceKind.allCases.map(\.rawValue),
                "description": "Device preset. Use 'custom' together with deviceWidth/deviceHeight when no preset fits.",
            ],
            "deviceWidth": ["type": "number", "description": "Logical width in CSS px. Required only for deviceKind=custom."],
            "deviceHeight": ["type": "number", "description": "Logical height in CSS px. Required only for deviceKind=custom."],
            "deviceScale": ["type": "number", "description": "Export scale factor. Defaults to the preset's scale."],
        ]
    }

    /// 从参数构造设备；`deviceKind` 缺失或非法时抛参数错误。
    static func device(from arguments: [String: ToolArgument]) throws -> PrototypeDevice {
        let raw = try required("deviceKind", arguments)
        guard let kind = PrototypeDeviceKind(rawValue: raw) else {
            throw ToolArgumentError.invalid("deviceKind")
        }
        if let preset = kind.preset {
            guard let scale = number(arguments, "deviceScale"), scale > 0 else { return preset }
            return PrototypeDevice(kind: preset.kind, width: preset.width, height: preset.height, scale: scale)
        }
        guard let width = number(arguments, "deviceWidth"), width > 0,
              let height = number(arguments, "deviceHeight"), height > 0 else {
            throw ToolArgumentError.invalid("deviceWidth/deviceHeight")
        }
        let scale = number(arguments, "deviceScale") ?? 2
        guard scale > 0 else { throw ToolArgumentError.invalid("deviceScale") }
        return PrototypeDevice(kind: .custom, width: width, height: height, scale: scale)
    }

    // MARK: - 参数访问器

    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        arguments[key]?.value as? String
    }

    static func number(_ arguments: [String: ToolArgument], _ key: String) -> Double? {
        guard let value = arguments[key]?.value else { return nil }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
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

    // MARK: - 本地化

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

    static func localizedErrorDescription(_ description: String) -> String {
        if description == "Plugin storage path is missing or invalid." {
            return "插件存储路径缺失或无效。请先打开一个项目。"
        }
        if description == "Screen order must list every screen exactly once." {
            return "屏幕顺序必须恰好列出全部屏幕各一次。"
        }
        if let suffix = description.dropPrefix("Prototype project not found at ") {
            return "找不到原型项目：\(suffix)"
        }
        if let suffix = description.dropPrefix("Screen not found: ") {
            return "找不到屏幕：\(suffix)"
        }
        if let suffix = description.dropPrefix("Invalid slug: ") {
            return "非法的 slug：\(suffix)"
        }
        if let suffix = description.dropPrefix("Reserved slug: ") {
            return "保留的 slug（不可用）：\(suffix)"
        }
        if let suffix = description.dropPrefix("Item already exists at ") {
            return "同名内容已存在：\(suffix)"
        }
        if let suffix = description.dropPrefix("Screen order references an unknown screen: ") {
            return "屏幕顺序引用了不存在的屏幕：\(suffix)"
        }
        if description == "Missing required argument: projectId" {
            return "缺少必填参数：projectId"
        }
        if description == "Missing required argument: screenId" {
            return "缺少必填参数：screenId"
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
