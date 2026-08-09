import AppStorePromoKit
import Foundation
import LumiKernel

private enum PromoToolSupport {
    static let store = AppStorePromoDocumentStore()

    static func projectPath(_ arguments: [String: LumiJSONValue], kernel: LumiKernel) throws -> String {
        let path = arguments.string("projectPath")?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? kernel.currentProjectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        guard !path.isEmpty else { throw AppStorePromoStoreError.invalidProjectPath }
        guard AppStorePromoDocumentStore.isPathAllowed(path, allowedDirectories: kernel.allowedDirectories) else {
            throw AppStorePromoStoreError.pathNotAllowed(path)
        }
        return path
    }

    static func required(_ key: String, _ arguments: [String: LumiJSONValue]) throws -> String {
        guard let value = arguments.string(key)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw ToolArgumentError.missing(key)
        }
        return value
    }

    static func notify(projectID: String? = nil, pageID: String? = nil) async {
        await MainActor.run { AppStorePromoWorkspaceStore.shared.reload(selectProject: projectID, page: pageID) }
    }

    static func projectSummary(_ project: AppStorePromoProject) -> String {
        let displays = AppStorePromoDisplaySpec.presets(for: project.deviceFamily)
            .map { "\($0.displayType)=\($0.width)x\($0.height)" }.joined(separator: ", ")
        let pages = project.pages.sorted(by: { $0.order < $1.order })
            .map { "\($0.order + 1):\($0.id)" }.joined(separator: ", ")
        return "projectId=\(project.id) title=\(project.title) appName=\(project.appName) family=\(project.deviceFamily.rawValue) locale=\(project.localeIdentifier) displayTypes=[\(displays)] pages=[\(pages)]"
    }

    static var projectPathProperty: LumiJSONValue {
        ["type": "string", "description": "Optional project path. Defaults to the current Lumi project."]
    }

    static func baseProperties(includePage: Bool = false) -> [String: LumiJSONValue] {
        var result: [String: LumiJSONValue] = [
            "projectId": ["type": "string", "description": "Promotional project slug."],
            "projectPath": projectPathProperty,
        ]
        if includePage { result["pageId"] = ["type": "string", "description": "Promotional page slug."] }
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

public struct ListAppStorePromoProjectsTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_list_projects", displayName: "List promo projects", description: "List App Store promotional HTML projects in the current project.")
    public init() {}
    public var inputSchema: LumiJSONValue { ["type": "object", "properties": ["projectPath": PromoToolSupport.projectPathProperty]] }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let path = try PromoToolSupport.projectPath(arguments, kernel: kernel)
        let projects = try PromoToolSupport.store.listProjects(projectPath: path)
        return projects.isEmpty ? "No App Store promotional projects found." : projects.map(PromoToolSupport.projectSummary).joined(separator: "\n")
    }
}

public struct CreateAppStorePromoProjectTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_create_project", displayName: "Create promo project", description: "Create an App Store promotional artwork project whose pages are complete HTML documents.")
    public init() {}
    public var inputSchema: LumiJSONValue {
        ["type": "object", "properties": [
            "slug": ["type": "string", "description": "Lowercase kebab-case project slug."],
            "title": ["type": "string"], "appName": ["type": "string"],
            "deviceFamily": ["type": "string", "enum": ["iphone", "ipad", "mac"]],
            "localeIdentifier": ["type": "string", "description": "Locale such as en-US or zh-Hans."],
            "projectPath": PromoToolSupport.projectPathProperty,
        ], "required": ["slug", "title", "appName", "deviceFamily"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let path = try PromoToolSupport.projectPath(arguments, kernel: kernel)
        let slug = try PromoToolSupport.required("slug", arguments)
        let familyRaw = try PromoToolSupport.required("deviceFamily", arguments)
        guard let family = AppStorePromoDeviceFamily(rawValue: familyRaw.lowercased()) else { throw PromoToolSupport.ToolArgumentError.invalid("deviceFamily") }
        let project = try PromoToolSupport.store.createProject(
            projectPath: path, slug: slug,
            title: try PromoToolSupport.required("title", arguments),
            appName: try PromoToolSupport.required("appName", arguments),
            deviceFamily: family,
            localeIdentifier: arguments.string("localeIdentifier") ?? "en-US"
        )
        await PromoToolSupport.notify(projectID: project.id)
        return "Created App Store promotional project.\n\(PromoToolSupport.projectSummary(project))\nNext: create one or more HTML pages with app_store_promo_create_page."
    }
}

public struct ReadAppStorePromoProjectTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_read_project", displayName: "Read promo project", description: "Read promotional project metadata, page order, and available exact App Store display sizes.")
    public init() {}
    public var inputSchema: LumiJSONValue { ["type": "object", "properties": .object(PromoToolSupport.baseProperties()), "required": ["projectId"]] }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let project = try PromoToolSupport.store.readProject(projectPath: PromoToolSupport.projectPath(arguments, kernel: kernel), projectSlug: PromoToolSupport.required("projectId", arguments))
        return PromoToolSupport.projectSummary(project)
    }
}

public struct CreateAppStorePromoPageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_create_page", displayName: "Create promo HTML page", description: "Create one promotional page from a valid responsive HTML template. Optionally supply the complete HTML document.")
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties()
        properties["pageId"] = ["type": "string", "description": "Lowercase kebab-case page slug."]
        properties["title"] = ["type": "string"]
        properties["html"] = ["type": "string", "description": "Optional complete HTML document. Never pass a fragment."]
        return ["type": "object", "properties": .object(properties), "required": ["projectId", "pageId", "title"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let path = try PromoToolSupport.projectPath(arguments, kernel: kernel)
        let projectID = try PromoToolSupport.required("projectId", arguments)
        let pageID = try PromoToolSupport.required("pageId", arguments)
        let resolved = try PromoToolSupport.store.createPage(
            projectPath: path, projectSlug: projectID, pageSlug: pageID,
            title: try PromoToolSupport.required("title", arguments), html: arguments.string("html")
        )
        await PromoToolSupport.notify(projectID: projectID, pageID: pageID)
        return "Created promotional HTML page. pageId=\(pageID) htmlPath=\(resolved.htmlURL.path) assetsPath=\(resolved.assetsDirectoryURL.path)\nEdit it with app_store_promo_replace_html or app_store_promo_patch_html, then call app_store_promo_preview_page."
    }
}

public struct ReadAppStorePromoHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_read_html", displayName: "Read promo HTML", description: "Read the full index.html for a promotional page before editing it.")
    public init() {}
    public var inputSchema: LumiJSONValue { ["type": "object", "properties": .object(PromoToolSupport.baseProperties(includePage: true)), "required": ["projectId", "pageId"]] }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let page = try PromoToolSupport.store.readPage(projectPath: PromoToolSupport.projectPath(arguments, kernel: kernel), projectSlug: PromoToolSupport.required("projectId", arguments), pageSlug: PromoToolSupport.required("pageId", arguments))
        return "htmlPath=\(page.htmlURL.path)\nassetsPath=\(page.assetsDirectoryURL.path)\n--- index.html ---\n\(page.html)"
    }
}

public struct ReplaceAppStorePromoHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_replace_html", displayName: "Replace promo HTML", description: "Validate and atomically replace a promotional page with a complete deterministic HTML document.")
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includePage: true)
        properties["html"] = ["type": "string", "description": "Complete HTML document including doctype, head, viewport, style, and body."]
        return ["type": "object", "properties": .object(properties), "required": ["projectId", "pageId", "html"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let path = try PromoToolSupport.projectPath(arguments, kernel: kernel)
        let projectID = try PromoToolSupport.required("projectId", arguments)
        let pageID = try PromoToolSupport.required("pageId", arguments)
        let page = try PromoToolSupport.store.replaceHTML(try PromoToolSupport.required("html", arguments), projectPath: path, projectSlug: projectID, pageSlug: pageID)
        await PromoToolSupport.notify(projectID: projectID, pageID: pageID)
        return "Promotional HTML updated and validated. htmlPath=\(page.htmlURL.path) bytes=\(page.html.utf8.count)\nCall app_store_promo_preview_page to inspect the rendered result."
    }
}

public struct PatchAppStorePromoHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_patch_html", displayName: "Patch promo HTML", description: "Apply an atomic batch of exact, unique text replacements to promotional HTML, then validate the complete result.")
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includePage: true)
        properties["operations"] = ["type": "array", "minItems": 1, "maxItems": 20, "items": ["type": "object", "properties": ["oldText": ["type": "string"], "newText": ["type": "string"]], "required": ["oldText", "newText"]]]
        return ["type": "object", "properties": .object(properties), "required": ["projectId", "pageId", "operations"]]
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
        let path = try PromoToolSupport.projectPath(arguments, kernel: kernel)
        let projectID = try PromoToolSupport.required("projectId", arguments)
        let pageID = try PromoToolSupport.required("pageId", arguments)
        let page = try PromoToolSupport.store.patchHTML(operations: operations, projectPath: path, projectSlug: projectID, pageSlug: pageID)
        await PromoToolSupport.notify(projectID: projectID, pageID: pageID)
        return "Applied \(operations.count) HTML patches atomically. htmlPath=\(page.htmlURL.path)\nCall app_store_promo_preview_page to inspect the rendered result."
    }
}

public struct ImportAppStorePromoAssetTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_import_asset", displayName: "Import promo asset", description: "Copy a local image into a promotional page assets directory and return the safe relative HTML path.")
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includePage: true)
        properties["sourcePath"] = ["type": "string"]
        properties["fileName"] = ["type": "string", "description": "Optional destination file name."]
        return ["type": "object", "properties": .object(properties), "required": ["projectId", "pageId", "sourcePath"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let sourcePath = try PromoToolSupport.required("sourcePath", arguments)
        guard AppStorePromoDocumentStore.isPathAllowed(sourcePath, allowedDirectories: kernel.allowedDirectories) else { throw AppStorePromoStoreError.pathNotAllowed(sourcePath) }
        let path = try PromoToolSupport.projectPath(arguments, kernel: kernel)
        let projectID = try PromoToolSupport.required("projectId", arguments)
        let pageID = try PromoToolSupport.required("pageId", arguments)
        let directory = try PromoToolSupport.store.assetsDirectoryURL(projectPath: path, projectSlug: projectID, pageSlug: pageID)
        let asset = try AppStorePromoAssetImporter().importImage(sourceURL: URL(fileURLWithPath: sourcePath), destinationDirectory: directory, preferredFileName: arguments.string("fileName"))
        await PromoToolSupport.notify(projectID: projectID, pageID: pageID)
        return "Imported promotional asset. relativePath=\(asset.relativePath) size=\(asset.pixelWidth)x\(asset.pixelHeight) absolutePath=\(asset.fileURL.path)"
    }
}

public struct PreviewAppStorePromoPageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_preview_page", displayName: "Preview promo page", description: "Render promotional HTML at an exact App Store display size and attach the PNG for visual inspection.")
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includePage: true)
        properties["displayType"] = ["type": "string", "description": "Exact App Store display type. Defaults to the first preset for the project family."]
        return ["type": "object", "properties": .object(properties), "required": ["projectId", "pageId"]]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let page = try PromoToolSupport.store.readPage(projectPath: PromoToolSupport.projectPath(arguments, kernel: kernel), projectSlug: PromoToolSupport.required("projectId", arguments), pageSlug: PromoToolSupport.required("pageId", arguments))
        let type = arguments.string("displayType") ?? AppStorePromoDisplaySpec.presets(for: page.project.deviceFamily).first?.displayType
        guard let type, let preset = AppStorePromoDisplaySpec.preset(for: type), preset.family == page.project.deviceFamily else { throw PromoToolSupport.ToolArgumentError.invalid("displayType") }
        let report = try PromoToolSupport.store.lintPage(projectPath: PromoToolSupport.projectPath(arguments, kernel: kernel), projectSlug: page.project.id, pageSlug: page.page.id)
        guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }
        let data = try await AppStorePromoHTMLExporter.exportPNG(html: page.html, fileURL: page.htmlURL, preset: preset)
        kernel.attachImage(.init(mimeType: "image/png", base64Data: data.base64EncodedString(), fileName: "\(page.page.id)-\(type).png"))
        return "Rendered promotional page at \(preset.width)x\(preset.height) for \(type). The PNG is attached to this tool result for visual inspection. Review it before further edits or export."
    }
}

public struct LintAppStorePromoProjectTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_lint_project", displayName: "Lint promo project", description: "Validate every promotional HTML page and all local asset references before export.")
    public init() {}
    public var inputSchema: LumiJSONValue { ["type": "object", "properties": .object(PromoToolSupport.baseProperties()), "required": ["projectId"]] }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let path = try PromoToolSupport.projectPath(arguments, kernel: kernel)
        let projectID = try PromoToolSupport.required("projectId", arguments)
        let project = try PromoToolSupport.store.readProject(projectPath: path, projectSlug: projectID)
        guard !project.pages.isEmpty else { return "Lint failed: project has no pages." }
        var lines: [String] = []
        var errors = 0
        for page in project.pages.sorted(by: { $0.order < $1.order }) {
            let report = try PromoToolSupport.store.lintPage(projectPath: path, projectSlug: projectID, pageSlug: page.id)
            errors += report.errors.count
            let details = report.issues.map { "\($0.severity.rawValue):\($0.code) \($0.message)" }.joined(separator: " | ")
            lines.append("page=\(page.id) \(report.isValid ? "valid" : "invalid") \(details)")
        }
        return (["Promo project lint: \(errors == 0 ? "PASS" : "FAIL") errors=\(errors)"] + lines).joined(separator: "\n")
    }
}

public struct ExportAppStorePromoProjectTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(id: "app_store_promo_export_project", displayName: "Export promo project", description: "Render every promotional HTML page to exact-size PNG files for one or more App Store display types.")
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties()
        properties["displayTypes"] = ["type": "array", "items": ["type": "string"], "description": "Optional display types. Defaults to all presets for the project family."]
        properties["outputDirectory"] = ["type": "string", "description": "Optional output directory. Defaults inside the promotional project directory."]
        properties["overwrite"] = ["type": "boolean", "description": "Allow replacing existing PNG files. Defaults to false."]
        return ["type": "object", "properties": .object(properties), "required": ["projectId"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { arguments.bool("overwrite") == true ? .high : .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let path = try PromoToolSupport.projectPath(arguments, kernel: kernel)
        let projectID = try PromoToolSupport.required("projectId", arguments)
        let project = try PromoToolSupport.store.readProject(projectPath: path, projectSlug: projectID)
        guard !project.pages.isEmpty else { throw PromoToolSupport.ToolArgumentError.invalid("project has no pages") }
        let requestedTypes = arguments.stringArray("displayTypes") ?? AppStorePromoDisplaySpec.presets(for: project.deviceFamily).map(\.displayType)
        let presets = try requestedTypes.map { type -> AppStorePromoDisplayPreset in
            guard let preset = AppStorePromoDisplaySpec.preset(for: type), preset.family == project.deviceFamily else { throw PromoToolSupport.ToolArgumentError.invalid("displayTypes") }
            return preset
        }
        let projectDirectory = try PromoToolSupport.store.projectDirectoryURL(projectPath: path, projectSlug: projectID)
        let outputDirectory = arguments.string("outputDirectory").map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) }
            ?? projectDirectory.appendingPathComponent("exports", isDirectory: true)
        let resolvedOutput = AppStorePromoDocumentStore.resolveProjectPath(outputDirectory.path)
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
            for pageMeta in project.pages.sorted(by: { $0.order < $1.order }) {
                let filename = String(format: "%02d-%@.png", pageMeta.order + 1, pageMeta.id)
                let destinationURL = outputDirectory
                    .appendingPathComponent(preset.displayType, isDirectory: true)
                    .appendingPathComponent(filename)
                if fileManager.fileExists(atPath: destinationURL.path), !overwrite {
                    throw AppStorePromoStoreError.alreadyExists(destinationURL.path)
                }

                let page = try PromoToolSupport.store.readPage(projectPath: path, projectSlug: projectID, pageSlug: pageMeta.id)
                let report = try PromoToolSupport.store.lintPage(projectPath: path, projectSlug: projectID, pageSlug: pageMeta.id)
                guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }
                let data = try await AppStorePromoHTMLExporter.exportPNG(html: page.html, fileURL: page.htmlURL, preset: preset)
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
