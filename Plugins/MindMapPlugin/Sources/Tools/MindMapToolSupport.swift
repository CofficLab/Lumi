import Foundation
import KernelLumi

/// 思维导图工具共享 helper（与 `IconToolSupport` 同构）。
enum MindMapToolSupport {
    static func language(_ kernel: KernelLumi?) -> LumiLanguagePreference {
        kernel?.language ?? .english
    }

    /// 返回去除首尾空白后非空的字符串，否则 nil。
    static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Scope & Map Resolution

    /// 当前已打开项目的路径（来自工具执行上下文，回退到 Runtime 缓存）。
    static func currentProjectPath(kernel: KernelLumi) async -> String? {
        if let fromContext = kernel.currentProjectPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fromContext.isEmpty {
            return fromContext
        }
        return await MainActor.run { MindMapRuntime.currentProjectPath }
    }

    /// 解析工具入参中的 scope：未指定时按是否有打开项目自动选择 project / app。
    static func resolveScope(_ arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> MindMapScope {
        if let raw = arguments.string("scope")?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !raw.isEmpty {
            guard let scope = MindMapScope(rawValue: raw) else {
                throw ToolArgumentError.invalid("scope")
            }
            return scope
        }
        let hasProject = await (currentProjectPath(kernel: kernel) != nil)
        return await MainActor.run { MindMapRuntime.defaultScope(hasOpenProject: hasProject) }
    }

    /// 解析工具要操作的思维导图：优先读可选 `mapId`+`scope`，缺省回退到选中思维导图。
    /// 返回思维导图快照（值类型）与其作用域。
    static func resolveMap(
        _ arguments: [String: LumiJSONValue],
        kernel: KernelLumi
    ) async throws -> (MindMap, MindMapScope) {
        let scope = try await resolveScope(arguments, kernel: kernel)
        let explicitId = arguments.string("mapId")?.trimmingCharacters(in: .whitespacesAndNewlines)

        return try await MainActor.run {
            let store = MindMapStore.shared
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

    /// 写操作完成后刷新 UI（按作用域重载并保持/切换选中）。
    static func notify(scope: MindMapScope, mapId: String?) async {
        await MainActor.run {
            MindMapStore.shared.reload(scope: scope, selectMapId: mapId)
        }
    }

    // MARK: - Schema Helpers

    /// 给工具 inputSchema 注入通用可选字段：scope（+ 可选 mapId）。
    static func baseProperties(includeScope: Bool = true, includeMapId: Bool = true) -> [String: LumiJSONValue] {
        var result: [String: LumiJSONValue] = [:]
        if includeScope {
            result["scope"] = [
                "type": "string",
                "enum": .array(MindMapScope.allCases.map { .string($0.rawValue) }),
                "description": "Storage scope: 'project' (current project .lumi/mind-map folder) or 'app' (application data directory). Defaults to 'project' when a project is open, else 'app'.",
            ]
        }
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

    // MARK: - Localized Strings

    static func localized(_ language: LumiLanguagePreference, en: String, zh: String) -> String {
        MindMapLocalization.localized(language, en: en, zh: zh)
    }

    static func error(_ error: Error, language: LumiLanguagePreference) -> String {
        localized(language, en: "Error: \(error.localizedDescription)", zh: "错误：\(localizedErrorDescription(error.localizedDescription))")
    }

    static func missingParameter(_ name: String, language: LumiLanguagePreference) -> String {
        localized(
            language,
            en: "Error: Missing required '\(name)' parameter.",
            zh: "错误：缺少必填参数 '\(name)'。"
        )
    }

    static func nodeSummary(_ node: MindMapNode, language: LumiLanguagePreference) -> String {
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
    func dropPrefix(_ prefix: String) -> Substring? {
        guard hasPrefix(prefix) else { return nil }
        return dropFirst(prefix.count)
    }
}
