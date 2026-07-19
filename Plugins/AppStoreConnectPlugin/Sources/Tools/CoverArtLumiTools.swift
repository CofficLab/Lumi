import Foundation
import LumiKernel

private enum CoverArtToolSupport {
    static let store = CoverArtDocumentStore()

    static func resolveProjectPath(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) -> String? {
        if let explicit = arguments["projectPath"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicit.isEmpty {
            return explicit
        }
        if let current = context.currentProjectPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !current.isEmpty {
            return current
        }
        return nil
    }

    static func validateAccess(projectPath: String, context: LumiToolExecutionContext) throws {
        guard CoverArtDocumentStore.isPathAllowed(projectPath, allowedDirectories: context.allowedDirectories) else {
            throw CoverArtStoreError.pathNotAllowed(projectPath)
        }
    }

    static func requireAppID(_ arguments: [String: LumiJSONValue]) -> String? {
        guard let appID = arguments["appID"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !appID.isEmpty else {
            return nil
        }
        return appID
    }

    static func requireSlug(_ arguments: [String: LumiJSONValue]) -> String? {
        guard let slug = arguments["slug"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !slug.isEmpty else {
            return nil
        }
        return slug
    }

    static func manifestSummary(_ manifest: CoverArtManifest, directory: URL) -> String {
        let sizes = manifest.previewSizes
            .map { "\($0.label) \($0.width)x\($0.height)" }
            .joined(separator: ", ")
        return [
            "- slug=\(manifest.id)",
            "title=\(manifest.title)",
            "deviceFamily=\(manifest.deviceFamily.rawValue)",
            "previewSizes=[\(sizes)]",
            "updatedAt=\(ISO8601DateFormatter().string(from: manifest.updatedAt))",
            "path=\(directory.appendingPathComponent(CoverArtDocumentStore.indexHTMLFileName).path)"
        ].joined(separator: " ")
    }

    static func parseDeviceFamily(_ raw: String) -> CoverArtDeviceFamily? {
        CoverArtDeviceFamily(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

struct ListAppStoreConnectCoverArtTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-cover-art",
        displayName: AppStoreConnectLocalization.string("List cover art documents"),
        description: AppStoreConnectLocalization.string("List HTML cover art documents stored under .lumi for an App Store Connect app.")
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "appID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("App Store Connect app identifier."))
                ]),
                "projectPath": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("Optional project path. Defaults to the current project."))
                ])
            ]),
            "required": .array([.string("appID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let appID = CoverArtToolSupport.requireAppID(arguments) else {
            return "Missing or empty appID."
        }
        guard let projectPath = CoverArtToolSupport.resolveProjectPath(arguments: arguments, context: context) else {
            return "Missing project path. Open a project or pass projectPath."
        }

        do {
            try CoverArtToolSupport.validateAccess(projectPath: projectPath, context: context)
            let manifests = try CoverArtToolSupport.store.list(projectPath: projectPath, appID: appID)
            if manifests.isEmpty {
                return "No cover art documents found for appID=\(appID) in \(CoverArtDocumentStore.relativeRoot)/\(appID)."
            }
            let root = try CoverArtToolSupport.store.rootURL(projectPath: projectPath, appID: appID)
            let lines = manifests.map {
                CoverArtToolSupport.manifestSummary($0, directory: root.appendingPathComponent($0.id, isDirectory: true))
            }
            return (["Cover art documents:"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list cover art: \(error.localizedDescription)"
        }
    }
}

struct ReadAppStoreConnectCoverArtTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.read-cover-art",
        displayName: AppStoreConnectLocalization.string("Read cover art document"),
        description: AppStoreConnectLocalization.string("Read a cover art manifest and full index.html for editing.")
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "appID": .object(["type": .string("string")]),
                "slug": .object(["type": .string("string")]),
                "projectPath": .object(["type": .string("string")])
            ]),
            "required": .array([.string("appID"), .string("slug")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let appID = CoverArtToolSupport.requireAppID(arguments) else { return "Missing appID." }
        guard let slug = CoverArtToolSupport.requireSlug(arguments) else { return "Missing slug." }
        guard let projectPath = CoverArtToolSupport.resolveProjectPath(arguments: arguments, context: context) else {
            return "Missing project path."
        }

        do {
            try CoverArtToolSupport.validateAccess(projectPath: projectPath, context: context)
            let document = try CoverArtToolSupport.store.read(projectPath: projectPath, appID: appID, slug: slug)
            return """
            Cover art document loaded.
            \(CoverArtToolSupport.manifestSummary(document.manifest, directory: document.directoryURL))
            htmlPath=\(document.indexHTMLURL.path)

            HTML must remain responsive within deviceFamily=\(document.manifest.deviceFamily.rawValue) and work at all preview sizes listed above.

            --- index.html ---
            \(document.html)
            """
        } catch {
            return "Failed to read cover art: \(error.localizedDescription)"
        }
    }
}

struct CreateAppStoreConnectCoverArtTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.create-cover-art",
        displayName: AppStoreConnectLocalization.string("Create cover art document"),
        description: AppStoreConnectLocalization.string("Create a new HTML cover art document from the default template.")
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "appID": .object(["type": .string("string")]),
                "slug": .object(["type": .string("string")]),
                "title": .object(["type": .string("string")]),
                "deviceFamily": .object([
                    "type": .string("string"),
                    "description": .string("Device family: iphone, ipad, or mac.")
                ]),
                "projectPath": .object(["type": .string("string")])
            ]),
            "required": .array([.string("appID"), .string("slug"), .string("deviceFamily")])
        ])
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let appID = CoverArtToolSupport.requireAppID(arguments) else { return "Missing appID." }
        guard let slug = CoverArtToolSupport.requireSlug(arguments) else { return "Missing slug." }
        guard let deviceFamilyRaw = arguments["deviceFamily"]?.stringValue,
              let deviceFamily = CoverArtToolSupport.parseDeviceFamily(deviceFamilyRaw) else {
            return "Missing or invalid deviceFamily. Use iphone, ipad, or mac."
        }
        guard let projectPath = CoverArtToolSupport.resolveProjectPath(arguments: arguments, context: context) else {
            return "Missing project path."
        }

        let title = arguments["title"]?.stringValue ?? slug

        do {
            try CoverArtToolSupport.validateAccess(projectPath: projectPath, context: context)
            let document = try CoverArtToolSupport.store.create(
                projectPath: projectPath,
                appID: appID,
                slug: slug,
                title: title,
                deviceFamily: deviceFamily
            )
            return """
            Cover art created.
            \(CoverArtToolSupport.manifestSummary(document.manifest, directory: document.directoryURL))
            htmlPath=\(document.indexHTMLURL.path)
            """
        } catch {
            return "Failed to create cover art: \(error.localizedDescription)"
        }
    }
}

struct UpdateAppStoreConnectCoverArtTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.update-cover-art",
        displayName: AppStoreConnectLocalization.string("Update cover art HTML"),
        description: AppStoreConnectLocalization.string("Replace the full index.html content for a cover art document.")
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "appID": .object(["type": .string("string")]),
                "slug": .object(["type": .string("string")]),
                "html": .object(["type": .string("string")]),
                "projectPath": .object(["type": .string("string")])
            ]),
            "required": .array([.string("appID"), .string("slug"), .string("html")])
        ])
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let appID = CoverArtToolSupport.requireAppID(arguments) else { return "Missing appID." }
        guard let slug = CoverArtToolSupport.requireSlug(arguments) else { return "Missing slug." }
        guard let html = arguments["html"]?.stringValue, !html.isEmpty else { return "Missing html." }
        guard let projectPath = CoverArtToolSupport.resolveProjectPath(arguments: arguments, context: context) else {
            return "Missing project path."
        }

        do {
            try CoverArtToolSupport.validateAccess(projectPath: projectPath, context: context)
            let document = try CoverArtToolSupport.store.writeHTML(
                html,
                projectPath: projectPath,
                appID: appID,
                slug: slug
            )
            return """
            Cover art updated.
            \(CoverArtToolSupport.manifestSummary(document.manifest, directory: document.directoryURL))
            htmlPath=\(document.indexHTMLURL.path)
            """
        } catch {
            return "Failed to update cover art: \(error.localizedDescription)"
        }
    }
}

struct ExportAppStoreConnectCoverArtTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.export-cover-art",
        displayName: AppStoreConnectLocalization.string("Export cover art PNG"),
        description: AppStoreConnectLocalization.string("Render a cover art HTML document to PNG and save it under the project .lumi exports folder.")
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "appID": .object(["type": .string("string")]),
                "slug": .object(["type": .string("string")]),
                "displayType": .object([
                    "type": .string("string"),
                    "description": .string("Screenshot display type within the document device family, e.g. APP_IPHONE_67.")
                ]),
                "projectPath": .object(["type": .string("string")]),
                "outputFileName": .object(["type": .string("string")])
            ]),
            "required": .array([.string("appID"), .string("slug")])
        ])
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let appID = CoverArtToolSupport.requireAppID(arguments) else { return "Missing appID." }
        guard let slug = CoverArtToolSupport.requireSlug(arguments) else { return "Missing slug." }
        guard let projectPath = CoverArtToolSupport.resolveProjectPath(arguments: arguments, context: context) else {
            return "Missing project path."
        }

        do {
            try CoverArtToolSupport.validateAccess(projectPath: projectPath, context: context)
            let document = try CoverArtToolSupport.store.read(projectPath: projectPath, appID: appID, slug: slug)
            let previewSizes = document.manifest.previewSizes
            let displayType = arguments["displayType"]?.stringValue ?? previewSizes.first?.displayType
            guard let displayType,
                  let previewSize = previewSizes.first(where: { $0.displayType == displayType }) else {
                let available = previewSizes.map(\.displayType).joined(separator: ", ")
                return "Missing or invalid displayType. Available: \(available)"
            }

            let expectedSize = ScreenshotDisplaySpec.Size(width: previewSize.width, height: previewSize.height)
            let pngData = try await CoverArtHTMLExporter.exportPNG(
                html: document.html,
                fileURL: document.indexHTMLURL,
                expectedSize: expectedSize
            )

            let exportsDirectory = URL(fileURLWithPath: CoverArtDocumentStore.resolveProjectPath(projectPath), isDirectory: true)
                .appendingPathComponent(".lumi/app-store-connect/exports", isDirectory: true)
            try FileManager.default.createDirectory(at: exportsDirectory, withIntermediateDirectories: true)

            let fileName = arguments["outputFileName"]?.stringValue?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "/", with: "-")
            let resolvedName = (fileName?.isEmpty == false ? fileName! : "\(slug)_\(displayType).png")
            let outputURL = exportsDirectory.appendingPathComponent(resolvedName.hasSuffix(".png") ? resolvedName : "\(resolvedName).png")
            try pngData.write(to: outputURL, options: .atomic)

            return """
            Cover art exported.
            slug=\(slug)
            deviceFamily=\(document.manifest.deviceFamily.rawValue)
            displayType=\(displayType)
            size=\(previewSize.width)x\(previewSize.height)
            outputPath=\(outputURL.path)
            bytes=\(pngData.count)
            """
        } catch {
            return "Failed to export cover art: \(error.localizedDescription)"
        }
    }
}
