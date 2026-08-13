import Foundation
import KernelLumi

enum IconToolSupport {
    static func language(_ kernel: KernelLumi?) -> LumiLanguagePreference {
        kernel?.language ?? .english
    }

    // MARK: - Scope & document resolution

    /// 当前已打开项目的路径（来自工具执行上下文，回退到 Runtime 缓存）。
    static func currentProjectPath(kernel: KernelLumi) async -> String? {
        if let fromContext = kernel.currentProjectPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fromContext.isEmpty {
            return fromContext
        }
        return await MainActor.run { IconDesignerRuntime.currentProjectPath }
    }

    /// 解析工具入参中的 scope：未指定时按是否有打开项目自动选择 project / app。
    static func resolveScope(_ arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> IconScope {
        if let raw = arguments.string("scope")?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !raw.isEmpty {
            guard let scope = IconScope(rawValue: raw) else {
                throw ToolArgumentError.invalid("scope")
            }
            return scope
        }
        let hasProject = await (currentProjectPath(kernel: kernel) != nil)
        return await MainActor.run { IconDesignerRuntime.defaultScope(hasOpenProject: hasProject) }
    }

    /// 指定 scope 的存储路径。无路径时抛 invalidStorageScope。
    static func storagePath(for scope: IconScope) async throws -> String {
        try await MainActor.run {
            let path = IconDocumentStore.shared.storagePath(for: scope)
            guard !path.isEmpty else { throw IconDocumentStoreError.invalidStorageScope }
            return path
        }
    }

    /// 解析工具要操作的文档：优先读可选 `documentId`+`scope`，缺省回退到选中文档。
    /// 返回文档快照（值类型）与其作用域。
    static func resolveDocument(
        _ arguments: [String: LumiJSONValue],
        kernel: KernelLumi
    ) async throws -> (IconDocument, IconScope) {
        let scope = try await resolveScope(arguments, kernel: kernel)
        let explicitId = arguments.string("documentId")?.trimmingCharacters(in: .whitespacesAndNewlines)

        return try await MainActor.run {
            let store = IconDocumentStore.shared
            if let explicitId, !explicitId.isEmpty {
                if let match = store.documents(for: scope).first(where: { $0.id == explicitId }) {
                    return (match, scope)
                }
                // 内存未命中：尝试从该作用域磁盘加载（文档可能尚未载入列表）。
                let path = store.storagePath(for: scope)
                if !path.isEmpty,
                   let match = IconDocumentFileStore.loadAll(storagePath: path).first(where: { $0.id == explicitId }) {
                    return (match, scope)
                }
                throw IconDocumentStoreError.documentNotFound(explicitId)
            }
            guard let selected = store.selectedDocument else {
                throw IconDocumentStoreError.noSelectedDocument
            }
            return (selected, store.selectedScope)
        }
    }

    /// 写操作完成后刷新 UI（按作用域重载并保持/切换选中）。
    static func notify(scope: IconScope, documentId: String?) async {
        await MainActor.run {
            IconDocumentStore.shared.reload(scope: scope, selectDocumentId: documentId)
        }
    }

    // MARK: - Schema helpers

    /// 给工具 inputSchema 注入通用可选字段：scope（+ 可选 documentId）。
    static func baseProperties(includeScope: Bool = true, includeDocumentId: Bool = true) -> [String: LumiJSONValue] {
        var result: [String: LumiJSONValue] = [:]
        if includeScope {
            result["scope"] = [
                "type": "string",
                "enum": .array(IconScope.allCases.map { .string($0.rawValue) }),
                "description": "Storage scope: 'project' (current project .lumi folder) or 'app' (application data directory). Defaults to 'project' when a project is open, else 'app'.",
            ]
        }
        if includeDocumentId {
            result["documentId"] = [
                "type": "string",
                "description": "Optional icon document id to target. If omitted, the currently selected document is used."
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

    static func localized(_ language: LumiLanguagePreference, en: String, zh: String) -> String {
        switch language {
        case .chinese:
            zh
        case .english:
            en
        }
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

    static func description(_ language: LumiLanguagePreference, en: String, zh: String) -> String {
        localized(language, en: en, zh: zh)
    }

    static func localizedErrorDescription(_ description: String) -> String {
        if description == "No icon document is selected." {
            return "未选中图标文档。"
        }
        if description == "No app icon document or candidate is selected." {
            return "未选中 App 图标文档或候选项。"
        }
        if let suffix = description.dropPrefix("Icon document not found: ") {
            return "找不到图标文档：\(suffix)"
        }
        if let suffix = description.dropPrefix("Icon layer not found: ") {
            return "找不到图层：\(suffix)"
        }
        if let suffix = description.dropPrefix("App icon artifact not found: ") {
            return "找不到 App 图标候选项：\(suffix)"
        }
        if let suffix = description.dropPrefix("Unsupported icon shape: ") {
            return "不支持的图标形状：\(suffix)"
        }
        if let suffix = description.dropPrefix("Image file not found: ") {
            return "找不到图片文件：\(suffix)"
        }
        if let suffix = description.dropPrefix("Unsupported image file: ") {
            return "不支持的图片文件：\(suffix)"
        }
        if let suffix = description.dropPrefix("Invalid source image: ") {
            return "无效源图片：\(suffix)"
        }
        if description.hasPrefix("Failed to render "), description.hasSuffix(" icon.") {
            return description
                .replacingOccurrences(of: "Failed to render ", with: "渲染 ")
                .replacingOccurrences(of: " icon.", with: " 图标失败。")
        }
        return description
    }

    static func string(_ arguments: [String: LumiJSONValue], _ key: String) -> String? {
        arguments.string(key)
    }

    static func double(_ arguments: [String: LumiJSONValue], _ key: String, default defaultValue: Double) -> Double {
        arguments.double(key) ?? defaultValue
    }

    static func optionalDouble(_ arguments: [String: LumiJSONValue], _ key: String) -> Double? {
        arguments.double(key)
    }

    static func bool(_ arguments: [String: LumiJSONValue], _ key: String, default defaultValue: Bool) -> Bool {
        arguments.bool(key) ?? defaultValue
    }

    static func color(_ arguments: [String: LumiJSONValue], _ key: String, default defaultValue: String) -> IconPaint {
        .color(string(arguments, key) ?? defaultValue)
    }

    static func layerSummary(_ layer: IconLayer, language: LumiLanguagePreference) -> String {
        switch language {
        case .chinese:
            """
            图层ID: \(layer.id)
            名称: \(layer.name)
            """
        case .english:
            """
            layerId: \(layer.id)
            name: \(layer.name)
            """
        }
    }
}

private extension String {
    func dropPrefix(_ prefix: String) -> Substring? {
        guard hasPrefix(prefix) else { return nil }
        return dropFirst(prefix.count)
    }
}
