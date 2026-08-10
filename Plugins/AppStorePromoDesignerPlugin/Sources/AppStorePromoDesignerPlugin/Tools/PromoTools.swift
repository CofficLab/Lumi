import AppStorePromoKit
import Foundation
import LumiKernel

private enum PromoToolSupport {
    static let store = AppStorePromoDocumentStore()

    /// 当前已打开项目的路径（来自工具执行上下文，回退到 Runtime 缓存）。
    static func currentProjectPath(kernel: LumiKernel) async -> String? {
        if let fromContext = kernel.currentProjectPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fromContext.isEmpty {
            return fromContext
        }
        return await MainActor.run { Runtime.currentProjectPath }
    }

    /// 解析工具入参中的 scope：未指定时按是否有打开项目自动选择 project / app。
    static func resolveScope(_ arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> Scope {
        if let raw = arguments.string("scope")?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !raw.isEmpty {
            guard let scope = Scope(rawValue: raw) else {
                throw ToolArgumentError.invalid("scope")
            }
            return scope
        }
        let hasProject = await (currentProjectPath(kernel: kernel) != nil)
        return await MainActor.run { Runtime.defaultScope(hasOpenProject: hasProject) }
    }

    /// 当前 scope 的存储路径。无路径时抛 invalidStoragePath。
    static func storagePath(for scope: Scope) async throws -> String {
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

    static func required(_ key: String, _ arguments: [String: LumiJSONValue]) throws -> String {
        guard let value = arguments.string(key)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw ToolArgumentError.missing(key)
        }
        return value
    }

    static func notify(scope: Scope, taskID: String? = nil, imageID: String? = nil) async {
        await MainActor.run { WorkspaceStore.shared.reload(scope: scope, selectTask: taskID, image: imageID) }
    }

    static func taskSummary(_ task: AppStorePromoTask, scope: Scope) -> String {
        let displays = AppStorePromoDisplaySpec.presets(for: task.deviceFamily)
            .map { "\($0.displayType)=\($0.width)x\($0.height)" }.joined(separator: ", ")
        let images = task.images.sorted(by: { $0.order < $1.order })
            .map { "\($0.order + 1):\($0.id)" }.joined(separator: ", ")
        return "scope=\(scope.rawValue) taskId=\(task.id) title=\(task.title) appName=\(task.appName) family=\(task.deviceFamily.rawValue) locale=\(task.localeIdentifier) displayTypes=[\(displays)] images=[\(images)]"
    }

    static func baseProperties(includeImage: Bool = false, includeScope: Bool = true) -> [String: LumiJSONValue] {
        var result: [String: LumiJSONValue] = [:]
        if includeScope {
            result["scope"] = [
                "type": "string",
                "enum": .array(Scope.allCases.map { .string($0.rawValue) }),
                "description": "Storage scope: 'project' (current project .lumi folder) or 'app' (application data directory). Defaults to 'project' when a project is open, else 'app'.",
            ]
        }
        result["taskId"] = ["type": "string", "description": "Promotional artwork task slug."]
        if includeImage {
            result["imageId"] = ["type": "string", "description": "Promotional image slug within the task."]
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
}

public struct ListPromoTasksTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_list_tasks",
        displayName: "List promo tasks",
        description: "List plugin-managed App Store promotional artwork tasks and their images, across project and app scopes."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "scope": [
                    "type": "string",
                    "enum": .array(["all"] + Scope.allCases.map { .string($0.rawValue) }),
                    "description": "Filter by scope: 'project', 'app', or 'all' (default).",
                ],
            ],
        ]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let scopeFilter = (arguments.string("scope") ?? "all").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let snapshot = await MainActor.run { () -> [(Scope, [AppStorePromoTask])] in
            let store = WorkspaceStore.shared
            var result: [(Scope, [AppStorePromoTask])] = []
            if scopeFilter == "all" || scopeFilter == Scope.project.rawValue {
                result.append((.project, store.projectTasks))
            }
            if scopeFilter == "all" || scopeFilter == Scope.app.rawValue {
                result.append((.app, store.appTasks))
            }
            return result
        }
        let lines = snapshot.flatMap { scope, tasks in
            tasks.isEmpty ? ["[scope=\(scope.rawValue)] (no tasks)"] : tasks.map { PromoToolSupport.taskSummary($0, scope: scope) }
        }
        if lines.isEmpty {
            return "No App Store promotional artwork tasks found."
        }
        return lines.joined(separator: "\n")
    }
}

public struct CreatePromoTaskTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_create_task",
        displayName: "Create promo task",
        description: "Create one plugin-managed promotional artwork task before generating its HTML images."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties: [String: LumiJSONValue] = PromoToolSupport.baseProperties()
        properties["slug"] = ["type": "string", "description": "Lowercase kebab-case task slug."]
        properties["title"] = ["type": "string"]
        properties["appName"] = ["type": "string"]
        properties["deviceFamily"] = ["type": "string", "enum": ["iphone", "ipad", "mac"]]
        properties["localeIdentifier"] = ["type": "string", "description": "Locale such as en-US or zh-Hans."]
        return ["type": "object", "properties": .object(properties), "required": ["slug", "title", "appName", "deviceFamily"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let slug = try PromoToolSupport.required("slug", arguments)
        let familyRaw = try PromoToolSupport.required("deviceFamily", arguments)
        guard let family = AppStorePromoDeviceFamily(rawValue: familyRaw.lowercased()) else {
            throw PromoToolSupport.ToolArgumentError.invalid("deviceFamily")
        }
        let task = try PromoToolSupport.store.createTask(
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            slug: slug,
            title: try PromoToolSupport.required("title", arguments),
            appName: try PromoToolSupport.required("appName", arguments),
            deviceFamily: family,
            localeIdentifier: arguments.string("localeIdentifier") ?? "en-US"
        )
        await PromoToolSupport.notify(scope: scope, taskID: task.id)
        return "Created App Store promotional artwork task (scope=\(scope.rawValue)).\n\(PromoToolSupport.taskSummary(task, scope: scope))\nNext: create one or more HTML images with app_store_promo_create_image."
    }
}

public struct ReadPromoTaskTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_read_task",
        displayName: "Read promo task",
        description: "Read task metadata, image order, and available exact App Store display sizes. Searches both project and app scopes by default."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        ["type": "object", "properties": .object(PromoToolSupport.baseProperties()), "required": ["taskId"]]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let resolvedScope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let scopesToTry: [Scope] = resolvedScope == .project ? [.project, .app] : [.app]
        var lastError: Error?
        for scope in scopesToTry {
            let path = try await PromoToolSupport.storagePath(for: scope)
            do {
                let task = try PromoToolSupport.store.readTask(storagePath: path, taskSlug: taskID)
                return PromoToolSupport.taskSummary(task, scope: scope)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? PromoToolSupport.ToolArgumentError.invalid("taskId")
    }
}

public struct CreatePromoImageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_create_image",
        displayName: "Create promo HTML image",
        description: "Create one image under a promotional task from a valid responsive HTML document."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["imageId"] = ["type": "string", "description": "Lowercase kebab-case image slug."]
        properties["title"] = ["type": "string"]
        properties["html"] = ["type": "string", "description": "Optional complete HTML document. Never pass a fragment."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId", "title"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        _ = try PromoToolSupport.store.createImage(
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: taskID, imageSlug: imageID,
            title: try PromoToolSupport.required("title", arguments),
            html: arguments.string("html")
        )
        await PromoToolSupport.notify(scope: scope, taskID: taskID, imageID: imageID)
        return "Created promotional HTML image (scope=\(scope.rawValue)). imageId=\(imageID)\nEdit it with app_store_promo_replace_html or app_store_promo_patch_html, then call app_store_promo_preview_image."
    }
}

public struct ReadPromoHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_read_html",
        displayName: "Read promo HTML",
        description: "Read the full index.html for a promotional image before editing it."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        ["type": "object", "properties": .object(PromoToolSupport.baseProperties(includeImage: true)), "required": ["taskId", "imageId"]]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let image = try PromoToolSupport.store.readImage(
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: try PromoToolSupport.required("taskId", arguments),
            imageSlug: try PromoToolSupport.required("imageId", arguments)
        )
        return "--- index.html ---\n\(image.html)"
    }
}

public struct ReplacePromoHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_replace_html",
        displayName: "Replace promo HTML",
        description: "Validate and atomically replace a promotional image with a complete deterministic HTML document."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["html"] = ["type": "string", "description": "Complete HTML document including doctype, head, viewport, style, and body."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId", "html"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        let image = try PromoToolSupport.store.replaceHTML(
            try PromoToolSupport.required("html", arguments),
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: taskID,
            imageSlug: imageID
        )
        await PromoToolSupport.notify(scope: scope, taskID: taskID, imageID: imageID)
        return "Promotional HTML updated and validated (scope=\(scope.rawValue)). bytes=\(image.html.utf8.count)\nCall app_store_promo_preview_image to inspect the rendered result."
    }
}

public struct PatchPromoHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_patch_html",
        displayName: "Patch promo HTML",
        description: "Apply an atomic batch of exact, unique text replacements to promotional HTML, then validate the complete result."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["operations"] = ["type": "array", "minItems": 1, "maxItems": 20, "items": ["type": "object", "properties": ["oldText": ["type": "string"], "newText": ["type": "string"]], "required": ["oldText", "newText"]]]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId", "operations"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard case .array(let rawOperations) = arguments["operations"], !rawOperations.isEmpty, rawOperations.count <= 20 else {
            throw PromoToolSupport.ToolArgumentError.invalid("operations")
        }
        let operations = try rawOperations.map { value -> AppStorePromoPatchOperation in
            guard case .object(let object) = value,
                  let oldText = object["oldText"]?.stringValue,
                  let newText = object["newText"]?.stringValue,
                  !oldText.isEmpty else { throw PromoToolSupport.ToolArgumentError.invalid("operations") }
            return .init(oldText: oldText, newText: newText)
        }
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        _ = try PromoToolSupport.store.patchHTML(
            operations: operations,
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: taskID,
            imageSlug: imageID
        )
        await PromoToolSupport.notify(scope: scope, taskID: taskID, imageID: imageID)
        return "Applied \(operations.count) HTML patches atomically (scope=\(scope.rawValue)).\nCall app_store_promo_preview_image to inspect the rendered result."
    }
}

public struct ImportPromoAssetTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_import_asset",
        displayName: "Import promo asset",
        description: "Copy a local image into the plugin-managed assets directory for one promotional image."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["sourcePath"] = ["type": "string"]
        properties["fileName"] = ["type": "string", "description": "Optional destination file name."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId", "sourcePath"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let sourcePath = try PromoToolSupport.required("sourcePath", arguments)
        guard AppStorePromoDocumentStore.isPathAllowed(sourcePath, allowedDirectories: kernel.allowedDirectories) else {
            throw AppStorePromoStoreError.pathNotAllowed(sourcePath)
        }
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        let directory = try PromoToolSupport.store.assetsDirectoryURL(
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: taskID,
            imageSlug: imageID
        )
        let asset = try AppStorePromoAssetImporter().importImage(
            sourceURL: URL(fileURLWithPath: sourcePath),
            destinationDirectory: directory,
            preferredFileName: arguments.string("fileName")
        )
        await PromoToolSupport.notify(scope: scope, taskID: taskID, imageID: imageID)
        return "Imported promotional asset (scope=\(scope.rawValue)). relativePath=\(asset.relativePath) size=\(asset.pixelWidth)x\(asset.pixelHeight)"
    }
}

public struct PreviewPromoImageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_preview_image",
        displayName: "Preview promo image",
        description: "Render one promotional HTML image at an exact App Store size and attach the PNG for visual inspection."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["displayType"] = ["type": "string", "description": "Exact App Store display type. Defaults to the first preset for the task family."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId"]]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let storagePath = try await PromoToolSupport.storagePath(for: scope)
        let image = try PromoToolSupport.store.readImage(
            storagePath: storagePath,
            taskSlug: try PromoToolSupport.required("taskId", arguments),
            imageSlug: try PromoToolSupport.required("imageId", arguments)
        )
        let type = arguments.string("displayType") ?? AppStorePromoDisplaySpec.presets(for: image.task.deviceFamily).first?.displayType
        guard let type, let preset = AppStorePromoDisplaySpec.preset(for: type), preset.family == image.task.deviceFamily else {
            throw PromoToolSupport.ToolArgumentError.invalid("displayType")
        }
        let report = try PromoToolSupport.store.lintImage(storagePath: storagePath, taskSlug: image.task.id, imageSlug: image.image.id)
        guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }
        let data = try await AppStorePromoHTMLExporter.exportPNG(html: image.html, fileURL: image.htmlURL, preset: preset)
        kernel.attachImage(.init(mimeType: "image/png", base64Data: data.base64EncodedString(), fileName: "\(image.image.id)-\(type).png"))
        return "Rendered promotional image at \(preset.width)x\(preset.height) for \(type) (scope=\(scope.rawValue)). The PNG is attached for visual inspection."
    }
}

public struct LintPromoTaskTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_lint_task",
        displayName: "Lint promo task",
        description: "Validate every HTML image and all local asset references in a promotional task."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        ["type": "object", "properties": .object(PromoToolSupport.baseProperties()), "required": ["taskId"]]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let storagePath = try await PromoToolSupport.storagePath(for: scope)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let task = try PromoToolSupport.store.readTask(storagePath: storagePath, taskSlug: taskID)
        guard !task.images.isEmpty else { return "Lint failed: task has no images." }
        var lines: [String] = []
        var errors = 0
        for image in task.images.sorted(by: { $0.order < $1.order }) {
            let report = try PromoToolSupport.store.lintImage(storagePath: storagePath, taskSlug: taskID, imageSlug: image.id)
            errors += report.errors.count
            let details = report.issues.map { "\($0.severity.rawValue):\($0.code) \($0.message)" }.joined(separator: " | ")
            lines.append("image=\(image.id) \(report.isValid ? "valid" : "invalid") \(details)")
        }
        return (["Promo task lint (scope=\(scope.rawValue)): \(errors == 0 ? "PASS" : "FAIL") errors=\(errors)"] + lines).joined(separator: "\n")
    }
}

public struct ExportPromoTaskTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_export_task",
        displayName: "Export promo task",
        description: "Render every HTML image in a task to an explicitly selected external directory."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties()
        properties["displayTypes"] = ["type": "array", "items": ["type": "string"], "description": "Optional display types. Defaults to all presets for the task family."]
        properties["outputDirectory"] = ["type": "string", "description": "Required user-selected export directory. Source files remain in plugin storage."]
        properties["overwrite"] = ["type": "boolean", "description": "Allow replacing existing PNG files. Defaults to false."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "outputDirectory"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        arguments.bool("overwrite") == true ? .high : .medium
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let storagePath = try await PromoToolSupport.storagePath(for: scope)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let task = try PromoToolSupport.store.readTask(storagePath: storagePath, taskSlug: taskID)
        guard !task.images.isEmpty else { throw PromoToolSupport.ToolArgumentError.invalid("task has no images") }
        let requestedTypes = arguments.stringArray("displayTypes") ?? AppStorePromoDisplaySpec.presets(for: task.deviceFamily).map(\.displayType)
        let presets = try requestedTypes.map { type -> AppStorePromoDisplayPreset in
            guard let preset = AppStorePromoDisplaySpec.preset(for: type), preset.family == task.deviceFamily else {
                throw PromoToolSupport.ToolArgumentError.invalid("displayTypes")
            }
            return preset
        }
        let outputDirectory = URL(fileURLWithPath: (try PromoToolSupport.required("outputDirectory", arguments) as NSString).expandingTildeInPath, isDirectory: true)
        let resolvedOutput = AppStorePromoDocumentStore.resolvePath(outputDirectory.path)
        guard AppStorePromoDocumentStore.isPathAllowed(resolvedOutput, allowedDirectories: kernel.allowedDirectories) else {
            throw AppStorePromoStoreError.pathNotAllowed(resolvedOutput)
        }
        let overwrite = arguments.bool("overwrite") ?? false
        let fileManager = FileManager.default
        let outputParent = outputDirectory.deletingLastPathComponent()
        try fileManager.createDirectory(at: outputParent, withIntermediateDirectories: true)
        let stagingDirectory = outputParent.appendingPathComponent(".app-store-promo-export-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDirectory) }

        struct StagedExport {
            let stagedURL: URL
            let destinationURL: URL
            let summary: String
        }
        var stagedExports: [StagedExport] = []
        for preset in presets {
            for imageMeta in task.images.sorted(by: { $0.order < $1.order }) {
                let filename = String(format: "%02d-%@.png", imageMeta.order + 1, imageMeta.id)
                let destinationURL = outputDirectory
                    .appendingPathComponent(preset.displayType, isDirectory: true)
                    .appendingPathComponent(filename)
                if fileManager.fileExists(atPath: destinationURL.path), !overwrite {
                    throw AppStorePromoStoreError.alreadyExists(destinationURL.path)
                }

                let image = try PromoToolSupport.store.readImage(storagePath: storagePath, taskSlug: taskID, imageSlug: imageMeta.id)
                let report = try PromoToolSupport.store.lintImage(storagePath: storagePath, taskSlug: taskID, imageSlug: imageMeta.id)
                guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }
                let data = try await AppStorePromoHTMLExporter.exportPNG(html: image.html, fileURL: image.htmlURL, preset: preset)
                let stagedURL = stagingDirectory.appendingPathComponent("rendered-\(stagedExports.count).png")
                try data.write(to: stagedURL, options: .atomic)
                stagedExports.append(StagedExport(
                    stagedURL: stagedURL,
                    destinationURL: destinationURL,
                    summary: "\(destinationURL.path) \(preset.width)x\(preset.height) \(data.count) bytes"
                ))
            }
        }

        let backupDirectory = stagingDirectory.appendingPathComponent("backups", isDirectory: true)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        var installedURLs: [URL] = []
        var backups: [(original: URL, backup: URL)] = []
        do {
            for (index, export) in stagedExports.enumerated() {
                try fileManager.createDirectory(at: export.destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: export.destinationURL.path) {
                    let backupURL = backupDirectory.appendingPathComponent("\(index).png")
                    try fileManager.moveItem(at: export.destinationURL, to: backupURL)
                    backups.append((export.destinationURL, backupURL))
                }
                try fileManager.moveItem(at: export.stagedURL, to: export.destinationURL)
                installedURLs.append(export.destinationURL)
            }
        } catch {
            for installedURL in installedURLs.reversed() {
                try? fileManager.removeItem(at: installedURL)
            }
            for backup in backups.reversed() {
                try? fileManager.moveItem(at: backup.backup, to: backup.original)
            }
            throw error
        }

        return (["Exported \(stagedExports.count) App Store promotional PNG files (scope=\(scope.rawValue))."] + stagedExports.map(\.summary)).joined(separator: "\n")
    }
}

// MARK: - Review (sub-agent 视角审核)

/// 渲染单张促销图，并以「资深 App Store 创意设计师」人设让 LLM 审核它，返回结构化修改意见。
///
/// 实现走「直接调用 provider」路径（`kernel.llmProvider?.generateText`）：
/// 一次性的 vision 调用，不写消息库、不触发 agent turn、不污染当前对话历史，
/// 只把审核意见作为 tool content 返回。对照 `AutoConversationTitleService` 的直接调用模式。
///
/// 工具是只读的（`riskLevel = .low`，沿用协议默认）：只评审、不修改 HTML。
public struct ReviewPromoImageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_review_image",
        displayName: "Review promo image",
        description: "Render a promotional image and ask a senior designer persona to critique it, returning concrete revision suggestions. Read-only; does not modify HTML."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["displayType"] = ["type": "string", "description": "Exact App Store display type. Defaults to the first preset for the task family."]
        properties["focus"] = ["type": "string", "description": "Optional area to focus the critique (e.g. 'typography', 'hierarchy', 'color'). Omit for a full review."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId"]]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard let providerManager = await MainActor.run(body: { kernel.llmProvider }) else {
            return "Review unavailable: no LLM provider registered."
        }

        // 1. 解析 scope + 读图 + lint（与 PreviewPromoImageTool 一致）。
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let storagePath = try await PromoToolSupport.storagePath(for: scope)
        let image = try PromoToolSupport.store.readImage(
            storagePath: storagePath,
            taskSlug: try PromoToolSupport.required("taskId", arguments),
            imageSlug: try PromoToolSupport.required("imageId", arguments)
        )
        let type = arguments.string("displayType") ?? AppStorePromoDisplaySpec.presets(for: image.task.deviceFamily).first?.displayType
        guard let type, let preset = AppStorePromoDisplaySpec.preset(for: type), preset.family == image.task.deviceFamily else {
            throw PromoToolSupport.ToolArgumentError.invalid("displayType")
        }
        let report = try PromoToolSupport.store.lintImage(storagePath: storagePath, taskSlug: image.task.id, imageSlug: image.image.id)
        guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }

        // 2. 渲染 PNG（复用 PreviewPromoImageTool 的渲染管线）。
        let data = try await AppStorePromoHTMLExporter.exportPNG(html: image.html, fileURL: image.htmlURL, preset: preset)

        // 3. 构造带图的直接 LLM 请求。
        let attachment = LumiImageAttachment(
            mimeType: "image/png",
            base64Data: data.base64EncodedString(),
            fileName: "\(image.image.id)-\(type).png"
        )
        let focus = arguments.string("focus")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = LumiLLMRequest(
            messages: Self.designerReviewMessages(task: image.task, image: image.image, displayType: type, focus: focus),
            model: "",
            tools: [],
            imageAttachments: [attachment]
        )

        // 4. 直接调 provider（不写消息库、不触发 turn）。provider/model 解析回退与
        //    AutoConversationTitleService 一致：优先全局选中，回退对话配置。
        let providerID = await MainActor.run { kernel.llmProvider?.selectedProviderID }
        let model = await MainActor.run { kernel.llmProvider?.selectedModel }
        do {
            let review = try await providerManager.generateText(request, providerID: providerID, model: model)
            let trimmed = review.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Design review returned an empty response. Try a different model or focus area." : trimmed
        } catch {
            return "Design review failed: \(error.localizedDescription). If the selected model does not support vision, switch to a vision-capable model and retry."
        }
    }

    // MARK: - 设计师人设 prompt

    /// 构造审核请求的消息序列：system（资深设计师人设 + 结构化输出约束）+ user（任务/图片/尺寸上下文）。
    private static func designerReviewMessages(
        task: AppStorePromoTask,
        image: AppStorePromoImage,
        displayType: String,
        focus: String?
    ) -> [LumiChatMessage] {
        // system 用占位 conversationID；直接调用路径不落库，不参与真实对话。
        let conversationID = UUID()
        let system = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: designerSystemPrompt(focus: focus)
        )
        let user = LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: """
            Please critique this App Store promotional artwork.

            Task: \(task.title)
            App: \(task.appName)
            Device family: \(task.deviceFamily.rawValue)
            Locale: \(task.localeIdentifier)
            Image: \(image.title) (order \(image.order + 1))
            Rendered display type: \(displayType)

            The image is attached. Review it strictly from a senior creative designer's perspective.
            """
        )
        return [system, user]
    }

    /// 资深 App Store 创意设计师人设，输出结构化审核意见。
    private static let designerSystemPromptBase = """
    You are a senior App Store creative designer with years of experience crafting high-converting promotional artwork (hero/promo images) for the App Store. You have an exceptional eye for visual hierarchy, typography, color, and composition on mobile and desktop canvases.

    You are given a rendered promotional image. Critique it as if reviewing a teammate's draft before it ships to the App Store. Be specific, honest, and constructive — never generic.

    Evaluate across these dimensions as relevant:
    - Visual hierarchy & focal point: what does the eye land on first? Is it the intended subject?
    - Typography & copy legibility: headline weight, size, contrast against the background, safe-area margins.
    - Color & contrast: palette cohesion, brand alignment, readability at small sizes.
    - Composition & whitespace: balance, alignment, crowding, padding relative to the device bezel.
    - Device-fit: how it reads at the exact App Store display size and aspect ratio.
    - First impression: would it stop a user from scrolling in the store?

    Output strictly in this structure:
    1. **Overall impression** (2-3 sentences).
    2. **Issues** — a prioritized list, most severe first. For each: what's wrong and why it matters.
    3. **Suggestions** — concrete, actionable changes that map directly to HTML/CSS edits (e.g. "increase h1 font-size", "add 8% top padding", "raise copy contrast"). Prefer the smallest change that fixes the issue.

    Keep it concise and skimmable. Do not rewrite the HTML for them — point, don't paint.
    """

    private static func designerSystemPrompt(focus: String?) -> String {
        let trimmed = focus?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return designerSystemPromptBase }
        return designerSystemPromptBase + "\n\nFocus this critique primarily on: \(trimmed). Still flag any critical issues in other dimensions, but keep the emphasis on the requested focus."
    }
}