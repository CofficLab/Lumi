import AppStorePromoKit
import Foundation
import LumiKernel

private enum PromoToolSupport {
    static let store = AppStorePromoDocumentStore()

    static func storagePath() async throws -> String {
        try await MainActor.run {
            guard let path = AppStorePromoRuntime.storageDirectory?.path, !path.isEmpty else {
                throw AppStorePromoStoreError.invalidStoragePath
            }
            return path
        }
    }

    static func required(_ key: String, _ arguments: [String: LumiJSONValue]) throws -> String {
        guard let value = arguments.string(key)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw ToolArgumentError.missing(key)
        }
        return value
    }

    static func notify(taskID: String? = nil, imageID: String? = nil) async {
        await MainActor.run { AppStorePromoWorkspaceStore.shared.reload(selectTask: taskID, image: imageID) }
    }

    static func taskSummary(_ task: AppStorePromoTask) -> String {
        let displays = AppStorePromoDisplaySpec.presets(for: task.deviceFamily)
            .map { "\($0.displayType)=\($0.width)x\($0.height)" }.joined(separator: ", ")
        let images = task.images.sorted(by: { $0.order < $1.order })
            .map { "\($0.order + 1):\($0.id)" }.joined(separator: ", ")
        return "taskId=\(task.id) title=\(task.title) appName=\(task.appName) family=\(task.deviceFamily.rawValue) locale=\(task.localeIdentifier) displayTypes=[\(displays)] images=[\(images)]"
    }

    static func baseProperties(includeImage: Bool = false) -> [String: LumiJSONValue] {
        var result: [String: LumiJSONValue] = [
            "taskId": ["type": "string", "description": "Promotional artwork task slug."],
        ]
        if includeImage { result["imageId"] = ["type": "string", "description": "Promotional image slug within the task."] }
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

public struct ListAppStorePromoTasksTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_list_tasks", displayName: "List promo tasks", description: "List plugin-managed App Store promotional artwork tasks and their images.")
    public init() {}
    public var inputSchema: LumiJSONValue { ["type": "object", "properties": [:]] }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let tasks = try PromoToolSupport.store.listTasks(storagePath: await PromoToolSupport.storagePath())
        return tasks.isEmpty ? "No App Store promotional artwork tasks found." : tasks.map(PromoToolSupport.taskSummary).joined(separator: "\n")
    }
}

public struct CreateAppStorePromoTaskTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_create_task", displayName: "Create promo task", description: "Create one plugin-managed promotional artwork task before generating its HTML images.")
    public init() {}
    public var inputSchema: LumiJSONValue {
        ["type": "object", "properties": [
            "slug": ["type": "string", "description": "Lowercase kebab-case task slug."],
            "title": ["type": "string"], "appName": ["type": "string"],
            "deviceFamily": ["type": "string", "enum": ["iphone", "ipad", "mac"]],
            "localeIdentifier": ["type": "string", "description": "Locale such as en-US or zh-Hans."],
        ], "required": ["slug", "title", "appName", "deviceFamily"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let slug = try PromoToolSupport.required("slug", arguments)
        let familyRaw = try PromoToolSupport.required("deviceFamily", arguments)
        guard let family = AppStorePromoDeviceFamily(rawValue: familyRaw.lowercased()) else { throw PromoToolSupport.ToolArgumentError.invalid("deviceFamily") }
        let task = try PromoToolSupport.store.createTask(
            storagePath: await PromoToolSupport.storagePath(), slug: slug,
            title: try PromoToolSupport.required("title", arguments),
            appName: try PromoToolSupport.required("appName", arguments),
            deviceFamily: family,
            localeIdentifier: arguments.string("localeIdentifier") ?? "en-US"
        )
        await PromoToolSupport.notify(taskID: task.id)
        return "Created App Store promotional artwork task.\n\(PromoToolSupport.taskSummary(task))\nNext: create one or more HTML images with app_store_promo_create_image."
    }
}

public struct ReadAppStorePromoTaskTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_read_task", displayName: "Read promo task", description: "Read task metadata, image order, and available exact App Store display sizes.")
    public init() {}
    public var inputSchema: LumiJSONValue { ["type": "object", "properties": .object(PromoToolSupport.baseProperties()), "required": ["taskId"]] }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let task = try PromoToolSupport.store.readTask(storagePath: await PromoToolSupport.storagePath(), taskSlug: PromoToolSupport.required("taskId", arguments))
        return PromoToolSupport.taskSummary(task)
    }
}

public struct CreateAppStorePromoImageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_create_image", displayName: "Create promo HTML image", description: "Create one image under a promotional task from a valid responsive HTML document.")
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties()
        properties["imageId"] = ["type": "string", "description": "Lowercase kebab-case image slug."]
        properties["title"] = ["type": "string"]
        properties["html"] = ["type": "string", "description": "Optional complete HTML document. Never pass a fragment."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId", "title"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        _ = try PromoToolSupport.store.createImage(
            storagePath: await PromoToolSupport.storagePath(), taskSlug: taskID, imageSlug: imageID,
            title: try PromoToolSupport.required("title", arguments), html: arguments.string("html")
        )
        await PromoToolSupport.notify(taskID: taskID, imageID: imageID)
        return "Created promotional HTML image. imageId=\(imageID)\nEdit it with app_store_promo_replace_html or app_store_promo_patch_html, then call app_store_promo_preview_image."
    }
}

public struct ReadAppStorePromoHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_read_html", displayName: "Read promo HTML", description: "Read the full index.html for a promotional image before editing it.")
    public init() {}
    public var inputSchema: LumiJSONValue { ["type": "object", "properties": .object(PromoToolSupport.baseProperties(includeImage: true)), "required": ["taskId", "imageId"]] }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let image = try PromoToolSupport.store.readImage(storagePath: await PromoToolSupport.storagePath(), taskSlug: PromoToolSupport.required("taskId", arguments), imageSlug: PromoToolSupport.required("imageId", arguments))
        return "--- index.html ---\n\(image.html)"
    }
}

public struct ReplaceAppStorePromoHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_replace_html", displayName: "Replace promo HTML", description: "Validate and atomically replace a promotional image with a complete deterministic HTML document.")
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["html"] = ["type": "string", "description": "Complete HTML document including doctype, head, viewport, style, and body."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId", "html"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        let image = try PromoToolSupport.store.replaceHTML(try PromoToolSupport.required("html", arguments), storagePath: await PromoToolSupport.storagePath(), taskSlug: taskID, imageSlug: imageID)
        await PromoToolSupport.notify(taskID: taskID, imageID: imageID)
        return "Promotional HTML updated and validated. bytes=\(image.html.utf8.count)\nCall app_store_promo_preview_image to inspect the rendered result."
    }
}

public struct PatchAppStorePromoHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_patch_html", displayName: "Patch promo HTML", description: "Apply an atomic batch of exact, unique text replacements to promotional HTML, then validate the complete result.")
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["operations"] = ["type": "array", "minItems": 1, "maxItems": 20, "items": ["type": "object", "properties": ["oldText": ["type": "string"], "newText": ["type": "string"]], "required": ["oldText", "newText"]]]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId", "operations"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard case .array(let rawOperations) = arguments["operations"], !rawOperations.isEmpty, rawOperations.count <= 20 else { throw PromoToolSupport.ToolArgumentError.invalid("operations") }
        let operations = try rawOperations.map { value -> AppStorePromoPatchOperation in
            guard case .object(let object) = value,
                  let oldText = object["oldText"]?.stringValue,
                  let newText = object["newText"]?.stringValue,
                  !oldText.isEmpty else { throw PromoToolSupport.ToolArgumentError.invalid("operations") }
            return .init(oldText: oldText, newText: newText)
        }
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        _ = try PromoToolSupport.store.patchHTML(operations: operations, storagePath: await PromoToolSupport.storagePath(), taskSlug: taskID, imageSlug: imageID)
        await PromoToolSupport.notify(taskID: taskID, imageID: imageID)
        return "Applied \(operations.count) HTML patches atomically.\nCall app_store_promo_preview_image to inspect the rendered result."
    }
}

public struct ImportAppStorePromoAssetTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_import_asset", displayName: "Import promo asset", description: "Copy a local image into the plugin-managed assets directory for one promotional image.")
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
        guard AppStorePromoDocumentStore.isPathAllowed(sourcePath, allowedDirectories: kernel.allowedDirectories) else { throw AppStorePromoStoreError.pathNotAllowed(sourcePath) }
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        let directory = try PromoToolSupport.store.assetsDirectoryURL(storagePath: await PromoToolSupport.storagePath(), taskSlug: taskID, imageSlug: imageID)
        let asset = try AppStorePromoAssetImporter().importImage(sourceURL: URL(fileURLWithPath: sourcePath), destinationDirectory: directory, preferredFileName: arguments.string("fileName"))
        await PromoToolSupport.notify(taskID: taskID, imageID: imageID)
        return "Imported promotional asset. relativePath=\(asset.relativePath) size=\(asset.pixelWidth)x\(asset.pixelHeight)"
    }
}

public struct PreviewAppStorePromoImageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_preview_image", displayName: "Preview promo image", description: "Render one promotional HTML image at an exact App Store size and attach the PNG for visual inspection.")
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["displayType"] = ["type": "string", "description": "Exact App Store display type. Defaults to the first preset for the task family."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId"]]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let storagePath = try await PromoToolSupport.storagePath()
        let image = try PromoToolSupport.store.readImage(storagePath: storagePath, taskSlug: PromoToolSupport.required("taskId", arguments), imageSlug: PromoToolSupport.required("imageId", arguments))
        let type = arguments.string("displayType") ?? AppStorePromoDisplaySpec.presets(for: image.task.deviceFamily).first?.displayType
        guard let type, let preset = AppStorePromoDisplaySpec.preset(for: type), preset.family == image.task.deviceFamily else { throw PromoToolSupport.ToolArgumentError.invalid("displayType") }
        let report = try PromoToolSupport.store.lintImage(storagePath: storagePath, taskSlug: image.task.id, imageSlug: image.image.id)
        guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }
        let data = try await AppStorePromoHTMLExporter.exportPNG(html: image.html, fileURL: image.htmlURL, preset: preset)
        kernel.attachImage(.init(mimeType: "image/png", base64Data: data.base64EncodedString(), fileName: "\(image.image.id)-\(type).png"))
        return "Rendered promotional image at \(preset.width)x\(preset.height) for \(type). The PNG is attached for visual inspection."
    }
}

public struct LintAppStorePromoTaskTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_lint_task", displayName: "Lint promo task", description: "Validate every HTML image and all local asset references in a promotional task.")
    public init() {}
    public var inputSchema: LumiJSONValue { ["type": "object", "properties": .object(PromoToolSupport.baseProperties()), "required": ["taskId"]] }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let storagePath = try await PromoToolSupport.storagePath()
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
        return (["Promo task lint: \(errors == 0 ? "PASS" : "FAIL") errors=\(errors)"] + lines).joined(separator: "\n")
    }
}

public struct ExportAppStorePromoTaskTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_export_task", displayName: "Export promo task", description: "Render every HTML image in a task to an explicitly selected external directory.")
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties()
        properties["displayTypes"] = ["type": "array", "items": ["type": "string"], "description": "Optional display types. Defaults to all presets for the task family."]
        properties["outputDirectory"] = ["type": "string", "description": "Required user-selected export directory. Source files remain in plugin storage."]
        properties["overwrite"] = ["type": "boolean", "description": "Allow replacing existing PNG files. Defaults to false."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "outputDirectory"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { arguments.bool("overwrite") == true ? .high : .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let storagePath = try await PromoToolSupport.storagePath()
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let task = try PromoToolSupport.store.readTask(storagePath: storagePath, taskSlug: taskID)
        guard !task.images.isEmpty else { throw PromoToolSupport.ToolArgumentError.invalid("task has no images") }
        let requestedTypes = arguments.stringArray("displayTypes") ?? AppStorePromoDisplaySpec.presets(for: task.deviceFamily).map(\.displayType)
        let presets = try requestedTypes.map { type -> AppStorePromoDisplayPreset in
            guard let preset = AppStorePromoDisplaySpec.preset(for: type), preset.family == task.deviceFamily else { throw PromoToolSupport.ToolArgumentError.invalid("displayTypes") }
            return preset
        }
        let outputDirectory = URL(fileURLWithPath: (try PromoToolSupport.required("outputDirectory", arguments) as NSString).expandingTildeInPath, isDirectory: true)
        let resolvedOutput = AppStorePromoDocumentStore.resolvePath(outputDirectory.path)
        guard AppStorePromoDocumentStore.isPathAllowed(resolvedOutput, allowedDirectories: kernel.allowedDirectories) else { throw AppStorePromoStoreError.pathNotAllowed(resolvedOutput) }
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

        return (["Exported \(stagedExports.count) App Store promotional PNG files."] + stagedExports.map(\.summary)).joined(separator: "\n")
    }
}
