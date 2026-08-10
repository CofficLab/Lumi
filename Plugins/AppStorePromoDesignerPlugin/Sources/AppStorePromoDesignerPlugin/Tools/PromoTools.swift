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