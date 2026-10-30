import KitAgentTool
import Foundation

/// 思维导图工具共享 helper（KernelCore 体系）。
///
/// 由旧版 `MindMapToolSupport.swift` 迁移而来，差异：
/// - 参数类型 `[String: LumiJSONValue]` → `[String: ToolArgument]`
/// - 移除 `kernel: KernelLumi` 上下文，scope / 项目路径直接读 `MindMapDesignerRuntime`
/// - 语言从 `kernel.language` → `LanguagePreference.current`（跟随系统/宿主注入）
enum MindMapToolSupport {
    /// 当前语言偏好（跟随系统 locale）。
    static var language: LanguagePreference { .current }

    // MARK: - Helpers

    /// 返回去除首尾空白后非空的字符串，否则 nil。
    static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Project Map Resolution

    /// 当前调用所属对话绑定的项目路径（规范化）。
    ///
    /// - 未绑定项目的对话、或非 Agent 调用时返回 `nil`（无约束）。
    static func scopedProjectPath() -> String? {
        if case .conversation(let projectPath) = MindMapConversationProjectScope.binding {
            return normalizedProjectPath(projectPath)
        }
        return nil
    }

    /// 当前调用所属项目的 store。
    ///
    /// 对话绑定了项目时使用该项目的 store（与 UI 当前项目不同时为隔离实例），
    /// 避免用户在对话切换期间导致数据写进另一个对话的项目；
    /// 对话未绑定项目时用 UI 当前项目的 store。
    @MainActor
    static func store() -> MindMapStore {
        MindMapDesignerRuntime.store(forProjectPath: scopedProjectPath())
    }

    /// 标准化项目路径，便于与 UI 当前项目路径比较。
    private static func normalizedProjectPath(_ path: String?) -> String? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
    }

    /// 所有工具都固定操作当前项目内的思维导图。
    static func resolveScope(_ arguments: [String: ToolArgument]) async throws -> MindMapScope {
        await MainActor.run { MindMapDesignerRuntime.defaultScope() }
    }

    /// 解析工具要操作的思维导图：优先读可选 mapId，缺省回退到选中思维导图。
    /// 返回思维导图快照与固定的项目作用域。
    static func resolveMap(_ arguments: [String: ToolArgument]) async throws -> (MindMap, MindMapScope) {
        let scope = try await resolveScope(arguments)
        let explicitId = string(arguments, "mapId")?.trimmingCharacters(in: .whitespacesAndNewlines)

        return try await MainActor.run {
            let store = store()
            guard !store.projectStoragePath.isEmpty else {
                throw MindMapStoreError.projectRequired
            }
            if let explicitId, !explicitId.isEmpty {
                if let match = store.maps(for: scope).first(where: { $0.id == explicitId }) {
                    return (match, scope)
                }
                // 内存未命中：尝试从该作用域磁盘加载。
                let path = store.storagePath(for: scope)
                if !path.isEmpty,
                   let match = MindMapFileStore.loadAll(storagePath: path).first(where: { $0.id == explicitId }) {
                    return (match, scope)
                }
                throw MindMapStoreError.mapNotFound(explicitId)
            }
            guard let selected = store.selectedMap else {
                throw MindMapStoreError.noSelectedMap
            }
            return (selected, store.selectedScope)
        }
    }

    /// 写操作完成后刷新项目内列表并保持选中。
    ///
    /// 跨项目写入时不刷新 UI：面板展示的是「当前打开项目」的内容，
    /// 刷新它只会把另一个项目的数据混进来。
    static func notify(scope: MindMapScope, mapId: String?) async {
        await MainActor.run {
            if let scoped = scopedProjectPath(),
               scoped != normalizedProjectPath(MindMapStore.shared.currentProjectPath) {
                return
            }
            MindMapStore.shared.reload(scope: scope, selectMapId: mapId)
        }
    }

    // MARK: - Schema Helpers

    /// 给工具 inputSchema 注入通用可选字段：可选 mapId。
    static func baseProperties(includeScope: Bool = true, includeMapId: Bool = true) -> [String: Any] {
        var result: [String: Any] = [:]
        if includeMapId {
            result["mapId"] = [
                "type": "string",
                "description": "Optional mind map id to target. If omitted, the currently selected mind map is used."
            ]
        }
        return result
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

    // MARK: - Localized Strings

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

    static func nodeSummary(_ node: MindMapNode, language: LanguagePreference) -> String {
        let preview = node.text.count > 40 ? String(node.text.prefix(40)) + "…" : node.text
        switch language {
        case .chinese:
            return "节点ID: \(node.id)\n文本: \(preview)"
        case .english:
            return "nodeId: \(node.id)\ntext: \(preview)"
        }
    }

    static func localizedErrorDescription(_ description: String) -> String {
        let map: [String: String] = [
            "Open a project before creating or editing a mind map.": "请先打开一个项目，再创建或编辑思维导图。",
            "No mind map is selected.": "未选中思维导图。",
            "The root node cannot be deleted.": "根节点不能删除。",
            "This move would create a cycle and is not allowed.": "该移动会形成环，不允许。",
        ]
        if let mapped = map[description] { return mapped }
        if let suffix = description.dropPrefix("Mind map not found: ") {
            return "找不到思维导图：\(suffix)"
        }
        if let suffix = description.dropPrefix("Mind map node not found: ") {
            return "找不到节点：\(suffix)"
        }
        return description
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
