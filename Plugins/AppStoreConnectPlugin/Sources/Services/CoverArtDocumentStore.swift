import Foundation

enum CoverArtStoreError: LocalizedError {
    case invalidProjectPath
    case invalidSlug(String)
    case invalidDisplayType(String)
    case alreadyExists(String)
    case notFound(String)
    case pathNotAllowed(String)

    var errorDescription: String? {
        switch self {
        case .invalidProjectPath:
            return AppStoreConnectLocalization.string("Project path is missing or invalid.")
        case .invalidSlug(let slug):
            return AppStoreConnectLocalization.string("Invalid cover art slug: %@", slug)
        case .invalidDisplayType(let type):
            return AppStoreConnectLocalization.string("Unknown screenshot display type: %@", type)
        case .alreadyExists(let path):
            return AppStoreConnectLocalization.string("Cover art already exists at %@", path)
        case .notFound(let path):
            return AppStoreConnectLocalization.string("Cover art not found at %@", path)
        case .pathNotAllowed(let path):
            return AppStoreConnectLocalization.string("Path is not allowed: %@", path)
        }
    }
}

struct CoverArtDocumentStore: @unchecked Sendable {
    static let indexHTMLFileName = "index.html"
    static let manifestFileName = "manifest.json"
    static let assetsDirectoryName = "assets"
    static let relativeRoot = ".lumi/app-store-connect/cover-art"

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func rootURL(projectPath: String, appID: String) throws -> URL {
        let resolved = Self.resolveProjectPath(projectPath)
        guard !resolved.isEmpty else { throw CoverArtStoreError.invalidProjectPath }
        return URL(fileURLWithPath: resolved, isDirectory: true)
            .appendingPathComponent(Self.relativeRoot, isDirectory: true)
            .appendingPathComponent(appID, isDirectory: true)
    }

    func documentDirectory(projectPath: String, appID: String, slug: String) throws -> URL {
        let normalizedSlug = try validatedSlug(slug)
        return try rootURL(projectPath: projectPath, appID: appID)
            .appendingPathComponent(normalizedSlug, isDirectory: true)
    }

    func list(projectPath: String, appID: String) throws -> [CoverArtManifest] {
        let root = try rootURL(projectPath: projectPath, appID: appID)
        guard fileManager.fileExists(atPath: root.path) else { return [] }

        let directories = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var manifests: [CoverArtManifest] = []
        for directory in directories {
            var isDirectory = ObjCBool(false)
            guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            let manifestURL = directory.appendingPathComponent(Self.manifestFileName)
            guard fileManager.fileExists(atPath: manifestURL.path),
                  let manifest = try? readManifest(at: manifestURL) else {
                continue
            }
            manifests.append(manifest)
        }

        return manifests.sorted { $0.updatedAt > $1.updatedAt }
    }

    func read(projectPath: String, appID: String, slug: String) throws -> CoverArtDocument {
        let directory = try documentDirectory(projectPath: projectPath, appID: appID, slug: slug)
        let manifestURL = directory.appendingPathComponent(Self.manifestFileName)
        let htmlURL = directory.appendingPathComponent(Self.indexHTMLFileName)

        guard fileManager.fileExists(atPath: manifestURL.path),
              fileManager.fileExists(atPath: htmlURL.path) else {
            throw CoverArtStoreError.notFound(directory.path)
        }

        let manifest = try readManifest(at: manifestURL)
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        return CoverArtDocument(manifest: manifest, html: html, directoryURL: directory)
    }

    @discardableResult
    func create(
        projectPath: String,
        appID: String,
        slug: String,
        title: String,
        displayType: String
    ) throws -> CoverArtDocument {
        guard let size = ScreenshotDisplaySpec.size(for: displayType) else {
            throw CoverArtStoreError.invalidDisplayType(displayType)
        }

        let normalizedSlug = try validatedSlug(slug)
        let directory = try documentDirectory(projectPath: projectPath, appID: appID, slug: normalizedSlug)
        guard !fileManager.fileExists(atPath: directory.path) else {
            throw CoverArtStoreError.alreadyExists(directory.path)
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = try assetsDirectoryURL(for: directory)

        let now = Date()
        let manifest = CoverArtManifest(
            id: normalizedSlug,
            title: title,
            displayType: displayType,
            width: size.width,
            height: size.height,
            createdAt: now,
            updatedAt: now
        )
        let html = CoverArtTemplateFactory.html(title: title, displayType: displayType, size: size)

        try writeManifest(manifest, to: directory)
        try writeHTML(html, to: directory)

        return CoverArtDocument(manifest: manifest, html: html, directoryURL: directory)
    }

    func writeHTML(
        _ html: String,
        projectPath: String,
        appID: String,
        slug: String
    ) throws -> CoverArtDocument {
        let directory = try documentDirectory(projectPath: projectPath, appID: appID, slug: slug)
        let manifestURL = directory.appendingPathComponent(Self.manifestFileName)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw CoverArtStoreError.notFound(directory.path)
        }

        var manifest = try readManifest(at: manifestURL)
        manifest.updatedAt = Date()
        try writeHTML(html, to: directory)
        try writeManifest(manifest, to: directory)
        return CoverArtDocument(manifest: manifest, html: html, directoryURL: directory)
    }

    func delete(projectPath: String, appID: String, slug: String) throws {
        let directory = try documentDirectory(projectPath: projectPath, appID: appID, slug: slug)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw CoverArtStoreError.notFound(directory.path)
        }
        try fileManager.removeItem(at: directory)
    }

    func assetsDirectoryURL(projectPath: String, appID: String, slug: String) throws -> URL {
        let directory = try documentDirectory(projectPath: projectPath, appID: appID, slug: slug)
        return try assetsDirectoryURL(for: directory)
    }

    // MARK: - Private

    private func assetsDirectoryURL(for documentDirectory: URL) throws -> URL {
        let assets = documentDirectory.appendingPathComponent(Self.assetsDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: assets, withIntermediateDirectories: true)
        return assets
    }

    private func validatedSlug(_ slug: String) throws -> String {
        guard let normalized = CoverArtSlugValidator.normalize(slug) else {
            throw CoverArtStoreError.invalidSlug(slug)
        }
        return normalized
    }

    private func readManifest(at url: URL) throws -> CoverArtManifest {
        let data = try Data(contentsOf: url)
        return try decoder.decode(CoverArtManifest.self, from: data)
    }

    private func writeManifest(_ manifest: CoverArtManifest, to directory: URL) throws {
        let data = try encoder.encode(manifest)
        let url = directory.appendingPathComponent(Self.manifestFileName)
        try data.write(to: url, options: .atomic)
    }

    private func writeHTML(_ html: String, to directory: URL) throws {
        let url = directory.appendingPathComponent(Self.indexHTMLFileName)
        try html.write(to: url, atomically: true, encoding: .utf8)
    }

    static func resolveProjectPath(_ projectPath: String) -> String {
        let expanded = (projectPath as NSString).expandingTildeInPath
        let resolved = URL(fileURLWithPath: expanded).resolvingSymlinksInPath().standardizedFileURL.path
        return resolved.hasSuffix("/") ? String(resolved.dropLast()) : resolved
    }

    static func isPathAllowed(_ path: String, allowedDirectories: [String]) -> Bool {
        guard !allowedDirectories.isEmpty else { return true }
        let resolved = resolveProjectPath(path)
        return allowedDirectories.contains { allowed in
            let normalizedAllowed = resolveProjectPath(allowed)
            return resolved == normalizedAllowed || resolved.hasPrefix("\(normalizedAllowed)/")
        }
    }
}
