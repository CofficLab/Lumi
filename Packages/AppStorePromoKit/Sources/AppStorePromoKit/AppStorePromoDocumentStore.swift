import Foundation

public enum AppStorePromoStoreError: LocalizedError, Equatable {
    case invalidProjectPath
    case invalidSlug(String)
    case alreadyExists(String)
    case notFound(String)
    case pageNotFound(String)
    case invalidHTML([AppStorePromoLintIssue])
    case patchTextMissing(String)
    case patchTextNotUnique(String)
    case pathNotAllowed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidProjectPath: "Project path is missing or invalid."
        case .invalidSlug(let slug): "Invalid slug: \(slug)"
        case .alreadyExists(let path): "Item already exists at \(path)"
        case .notFound(let path): "Project not found at \(path)"
        case .pageNotFound(let page): "Page not found: \(page)"
        case .invalidHTML(let issues): "HTML validation failed: \(issues.map(\.message).joined(separator: " "))"
        case .patchTextMissing(let value): "Patch text was not found: \(value.prefix(80))"
        case .patchTextNotUnique(let value): "Patch text must occur exactly once: \(value.prefix(80))"
        case .pathNotAllowed(let path): "Path is outside the allowed directories: \(path)"
        }
    }
}

public struct AppStorePromoPatchOperation: Codable, Equatable, Sendable {
    public let oldText: String
    public let newText: String

    public init(oldText: String, newText: String) {
        self.oldText = oldText
        self.newText = newText
    }
}

public struct AppStorePromoDocumentStore: @unchecked Sendable {
    public static let manifestFileName = "manifest.json"
    public static let pagesDirectoryName = "pages"
    public static let assetsDirectoryName = "assets"
    public static let defaultRelativeRoot = ".lumi/app-store-promo"

    public let relativeRoot: String
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let linter: AppStorePromoHTMLLinter

    public init(
        relativeRoot: String = AppStorePromoDocumentStore.defaultRelativeRoot,
        fileManager: FileManager = .default,
        linter: AppStorePromoHTMLLinter = .init()
    ) {
        self.relativeRoot = relativeRoot
        self.fileManager = fileManager
        self.linter = linter
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func rootURL(projectPath: String) throws -> URL {
        let resolved = Self.resolveProjectPath(projectPath)
        guard !resolved.isEmpty else { throw AppStorePromoStoreError.invalidProjectPath }
        return URL(fileURLWithPath: resolved, isDirectory: true)
            .appendingPathComponent(relativeRoot, isDirectory: true)
    }

    public func projectDirectoryURL(projectPath: String, projectSlug: String) throws -> URL {
        let slug = try Self.validatedSlug(projectSlug)
        return try rootURL(projectPath: projectPath).appendingPathComponent(slug, isDirectory: true)
    }

    public func listProjects(projectPath: String) throws -> [AppStorePromoProject] {
        let root = try rootURL(projectPath: projectPath)
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        return try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).compactMap { directory in
            try? readManifest(at: directory.appendingPathComponent(Self.manifestFileName))
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    public func createProject(
        projectPath: String,
        slug: String,
        title: String,
        appName: String,
        deviceFamily: AppStorePromoDeviceFamily,
        localeIdentifier: String
    ) throws -> AppStorePromoProject {
        let normalized = try Self.validatedSlug(slug)
        let directory = try projectDirectoryURL(projectPath: projectPath, projectSlug: normalized)
        guard !fileManager.fileExists(atPath: directory.path) else {
            throw AppStorePromoStoreError.alreadyExists(directory.path)
        }
        try fileManager.createDirectory(
            at: directory.appendingPathComponent(Self.pagesDirectoryName, isDirectory: true),
            withIntermediateDirectories: true
        )
        let project = AppStorePromoProject(
            id: normalized,
            title: title.isEmpty ? normalized : title,
            appName: appName,
            deviceFamily: deviceFamily,
            localeIdentifier: localeIdentifier.isEmpty ? "en-US" : localeIdentifier
        )
        try writeManifest(project, to: directory)
        return project
    }

    public func readProject(projectPath: String, projectSlug: String) throws -> AppStorePromoProject {
        let directory = try projectDirectoryURL(projectPath: projectPath, projectSlug: projectSlug)
        let url = directory.appendingPathComponent(Self.manifestFileName)
        guard fileManager.fileExists(atPath: url.path) else { throw AppStorePromoStoreError.notFound(directory.path) }
        return try readManifest(at: url)
    }

    @discardableResult
    public func createPage(
        projectPath: String,
        projectSlug: String,
        pageSlug: String,
        title: String,
        html: String? = nil
    ) throws -> AppStorePromoResolvedPage {
        let normalizedPageSlug = try Self.validatedSlug(pageSlug)
        let projectDirectory = try projectDirectoryURL(projectPath: projectPath, projectSlug: projectSlug)
        var project = try readProject(projectPath: projectPath, projectSlug: projectSlug)
        let pageDirectory = projectDirectory
            .appendingPathComponent(Self.pagesDirectoryName, isDirectory: true)
            .appendingPathComponent(normalizedPageSlug, isDirectory: true)
        guard !fileManager.fileExists(atPath: pageDirectory.path),
              !project.pages.contains(where: { $0.id == normalizedPageSlug }) else {
            throw AppStorePromoStoreError.alreadyExists(pageDirectory.path)
        }
        try fileManager.createDirectory(
            at: pageDirectory.appendingPathComponent(Self.assetsDirectoryName, isDirectory: true),
            withIntermediateDirectories: true
        )
        let now = Date()
        let page = AppStorePromoPage(
            id: normalizedPageSlug,
            title: title.isEmpty ? normalizedPageSlug : title,
            order: project.pages.count,
            createdAt: now,
            updatedAt: now
        )
        let resolvedHTML = html ?? AppStorePromoTemplateFactory.html(
            title: page.title,
            appName: project.appName,
            family: project.deviceFamily
        )
        let report = linter.lint(html: resolvedHTML, documentDirectory: pageDirectory)
        guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }
        try resolvedHTML.write(
            to: pageDirectory.appendingPathComponent(page.htmlFileName),
            atomically: true,
            encoding: .utf8
        )
        project.pages.append(page)
        project.updatedAt = now
        try writeManifest(project, to: projectDirectory)
        return AppStorePromoResolvedPage(project: project, page: page, directoryURL: pageDirectory, html: resolvedHTML)
    }

    public func readPage(
        projectPath: String,
        projectSlug: String,
        pageSlug: String
    ) throws -> AppStorePromoResolvedPage {
        let projectDirectory = try projectDirectoryURL(projectPath: projectPath, projectSlug: projectSlug)
        let project = try readProject(projectPath: projectPath, projectSlug: projectSlug)
        guard let page = project.pages.first(where: { $0.id == pageSlug }) else {
            throw AppStorePromoStoreError.pageNotFound(pageSlug)
        }
        let directory = projectDirectory
            .appendingPathComponent(Self.pagesDirectoryName, isDirectory: true)
            .appendingPathComponent(page.id, isDirectory: true)
        let htmlURL = directory.appendingPathComponent(page.htmlFileName)
        guard fileManager.fileExists(atPath: htmlURL.path) else { throw AppStorePromoStoreError.pageNotFound(pageSlug) }
        return AppStorePromoResolvedPage(
            project: project,
            page: page,
            directoryURL: directory,
            html: try String(contentsOf: htmlURL, encoding: .utf8)
        )
    }

    @discardableResult
    public func replaceHTML(
        _ html: String,
        projectPath: String,
        projectSlug: String,
        pageSlug: String
    ) throws -> AppStorePromoResolvedPage {
        var resolved = try readPage(projectPath: projectPath, projectSlug: projectSlug, pageSlug: pageSlug)
        let report = linter.lint(html: html, documentDirectory: resolved.directoryURL)
        guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }
        try html.write(to: resolved.htmlURL, atomically: true, encoding: .utf8)

        var project = resolved.project
        guard let index = project.pages.firstIndex(where: { $0.id == pageSlug }) else {
            throw AppStorePromoStoreError.pageNotFound(pageSlug)
        }
        let now = Date()
        project.pages[index].updatedAt = now
        project.updatedAt = now
        try writeManifest(project, to: try projectDirectoryURL(projectPath: projectPath, projectSlug: projectSlug))
        resolved = AppStorePromoResolvedPage(
            project: project,
            page: project.pages[index],
            directoryURL: resolved.directoryURL,
            html: html
        )
        return resolved
    }

    @discardableResult
    public func patchHTML(
        operations: [AppStorePromoPatchOperation],
        projectPath: String,
        projectSlug: String,
        pageSlug: String
    ) throws -> AppStorePromoResolvedPage {
        let current = try readPage(projectPath: projectPath, projectSlug: projectSlug, pageSlug: pageSlug)
        var candidate = current.html
        for operation in operations {
            let count = candidate.components(separatedBy: operation.oldText).count - 1
            guard count > 0 else { throw AppStorePromoStoreError.patchTextMissing(operation.oldText) }
            guard count == 1 else { throw AppStorePromoStoreError.patchTextNotUnique(operation.oldText) }
            candidate = candidate.replacingOccurrences(of: operation.oldText, with: operation.newText)
        }
        return try replaceHTML(
            candidate,
            projectPath: projectPath,
            projectSlug: projectSlug,
            pageSlug: pageSlug
        )
    }

    public func lintPage(projectPath: String, projectSlug: String, pageSlug: String) throws -> AppStorePromoLintReport {
        let page = try readPage(projectPath: projectPath, projectSlug: projectSlug, pageSlug: pageSlug)
        return linter.lint(html: page.html, documentDirectory: page.directoryURL)
    }

    public func assetsDirectoryURL(projectPath: String, projectSlug: String, pageSlug: String) throws -> URL {
        let page = try readPage(projectPath: projectPath, projectSlug: projectSlug, pageSlug: pageSlug)
        let url = page.assetsDirectoryURL
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func resolveProjectPath(_ projectPath: String) -> String {
        let expanded = (projectPath as NSString).expandingTildeInPath
        let resolved = URL(fileURLWithPath: expanded).resolvingSymlinksInPath().standardizedFileURL.path
        return resolved.hasSuffix("/") ? String(resolved.dropLast()) : resolved
    }

    public static func isPathAllowed(_ path: String, allowedDirectories: [String]) -> Bool {
        guard !allowedDirectories.isEmpty else { return true }
        let resolved = resolveProjectPath(path)
        return allowedDirectories.contains { allowed in
            let normalized = resolveProjectPath(allowed)
            return resolved == normalized || resolved.hasPrefix(normalized + "/")
        }
    }

    public static func validatedSlug(_ raw: String) throws -> String {
        let slug = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pattern = #"^[a-z0-9]+(?:-[a-z0-9]+)*$"#
        guard !slug.isEmpty, slug.range(of: pattern, options: .regularExpression) != nil else {
            throw AppStorePromoStoreError.invalidSlug(raw)
        }
        return slug
    }

    private func readManifest(at url: URL) throws -> AppStorePromoProject {
        try decoder.decode(AppStorePromoProject.self, from: Data(contentsOf: url))
    }

    private func writeManifest(_ project: AppStorePromoProject, to directory: URL) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(project).write(
            to: directory.appendingPathComponent(Self.manifestFileName),
            options: .atomic
        )
    }
}
