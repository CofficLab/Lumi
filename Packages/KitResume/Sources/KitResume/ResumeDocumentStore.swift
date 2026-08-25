import Foundation

public enum ResumeStoreError: LocalizedError, Equatable {
    case invalidStoragePath
    case invalidSlug(String)
    case alreadyExists(String)
    case notFound(String)
    case invalidHTML([ResumeLintIssue])
    case patchTextMissing(String)
    case patchTextNotUnique(String)
    case pathNotAllowed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidStoragePath: "Plugin storage path is missing or invalid."
        case .invalidSlug(let slug): "Invalid slug: \(slug)"
        case .alreadyExists(let path): "Item already exists at \(path)"
        case .notFound(let path): "Resume not found at \(path)"
        case .invalidHTML(let issues): "HTML validation failed: \(issues.map(\.message).joined(separator: " "))"
        case .patchTextMissing(let value): "Patch text was not found: \(value.prefix(80))"
        case .patchTextNotUnique(let value): "Patch text must occur exactly once: \(value.prefix(80))"
        case .pathNotAllowed(let path): "Path is outside the allowed directories: \(path)"
        }
    }
}

public struct ResumePatchOperation: Codable, Equatable, Sendable {
    public let oldText: String
    public let newText: String

    public init(oldText: String, newText: String) {
        self.oldText = oldText
        self.newText = newText
    }
}

/// 简历文档存取：`resumes/<slug>/{manifest.json, index.html, assets/}`。
public struct ResumeDocumentStore: @unchecked Sendable {
    public static let manifestFileName = "manifest.json"
    public static let htmlFileName = "index.html"
    public static let assetsDirectoryName = "assets"
    public static let defaultRelativeRoot = "resumes"

    public let relativeRoot: String
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let linter: ResumeHTMLLinter

    public init(
        relativeRoot: String = ResumeDocumentStore.defaultRelativeRoot,
        fileManager: FileManager = .default,
        linter: ResumeHTMLLinter = .init()
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

    // MARK: - Paths

    public func rootURL(storagePath: String) throws -> URL {
        let resolved = Self.resolvePath(storagePath)
        guard !resolved.isEmpty else { throw ResumeStoreError.invalidStoragePath }
        return URL(fileURLWithPath: resolved, isDirectory: true)
            .appendingPathComponent(relativeRoot, isDirectory: true)
    }

    public func resumeDirectoryURL(storagePath: String, slug: String) throws -> URL {
        let normalized = try Self.validatedSlug(slug)
        return try rootURL(storagePath: storagePath).appendingPathComponent(normalized, isDirectory: true)
    }

    // MARK: - CRUD

    public func listResumes(storagePath: String) throws -> [ResumeDocument] {
        let root = try rootURL(storagePath: storagePath)
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
    public func createResume(
        storagePath: String,
        slug: String,
        title: String,
        paper: ResumePaperKind,
        template: ResumeTemplateKind
    ) throws -> ResumeResolvedDocument {
        let normalized = try Self.validatedSlug(slug)
        let directory = try resumeDirectoryURL(storagePath: storagePath, slug: normalized)
        guard !fileManager.fileExists(atPath: directory.path) else {
            throw ResumeStoreError.alreadyExists(directory.path)
        }
        try fileManager.createDirectory(
            at: directory.appendingPathComponent(Self.assetsDirectoryName, isDirectory: true),
            withIntermediateDirectories: true
        )
        let document = ResumeDocument(
            id: normalized,
            title: title.isEmpty ? normalized : title,
            paper: paper,
            template: template
        )
        let html = ResumeTemplateFactory.html(title: document.title, template: template, paper: paper)
        let report = linter.lint(html: html, paper: paper, documentDirectory: directory)
        guard report.isValid else { throw ResumeStoreError.invalidHTML(report.errors) }
        try html.write(
            to: directory.appendingPathComponent(Self.htmlFileName),
            atomically: true,
            encoding: .utf8
        )
        try writeManifest(document, to: directory)
        return ResumeResolvedDocument(document: document, directoryURL: directory, html: html)
    }

    public func readResume(storagePath: String, slug: String) throws -> ResumeResolvedDocument {
        let directory = try resumeDirectoryURL(storagePath: storagePath, slug: slug)
        let manifestURL = directory.appendingPathComponent(Self.manifestFileName)
        guard fileManager.fileExists(atPath: manifestURL.path) else { throw ResumeStoreError.notFound(directory.path) }
        let document = try readManifest(at: manifestURL)
        let htmlURL = directory.appendingPathComponent(Self.htmlFileName)
        guard fileManager.fileExists(atPath: htmlURL.path) else { throw ResumeStoreError.notFound(directory.path) }
        return ResumeResolvedDocument(
            document: document,
            directoryURL: directory,
            html: try String(contentsOf: htmlURL, encoding: .utf8),
            htmlURL: htmlURL
        )
    }

    @discardableResult
    public func replaceHTML(
        _ html: String,
        storagePath: String,
        slug: String
    ) throws -> ResumeResolvedDocument {
        let current = try readResume(storagePath: storagePath, slug: slug)
        let report = linter.lint(html: html, paper: current.document.paper, documentDirectory: current.directoryURL)
        guard report.isValid else { throw ResumeStoreError.invalidHTML(report.errors) }
        try html.write(to: current.htmlURL, atomically: true, encoding: .utf8)
        var document = current.document
        document.updatedAt = Date()
        try writeManifest(document, to: current.directoryURL)
        return ResumeResolvedDocument(document: document, directoryURL: current.directoryURL, html: html, htmlURL: current.htmlURL)
    }

    @discardableResult
    public func patchHTML(
        operations: [ResumePatchOperation],
        storagePath: String,
        slug: String
    ) throws -> ResumeResolvedDocument {
        let current = try readResume(storagePath: storagePath, slug: slug)
        var candidate = current.html
        for operation in operations {
            let count = candidate.components(separatedBy: operation.oldText).count - 1
            guard count > 0 else { throw ResumeStoreError.patchTextMissing(operation.oldText) }
            guard count == 1 else { throw ResumeStoreError.patchTextNotUnique(operation.oldText) }
            candidate = candidate.replacingOccurrences(of: operation.oldText, with: operation.newText)
        }
        return try replaceHTML(candidate, storagePath: storagePath, slug: slug)
    }

    public func lintResume(storagePath: String, slug: String) throws -> ResumeLintReport {
        let resume = try readResume(storagePath: storagePath, slug: slug)
        return linter.lint(html: resume.html, paper: resume.document.paper, documentDirectory: resume.directoryURL)
    }

    public func assetsDirectoryURL(storagePath: String, slug: String) throws -> URL {
        let resume = try readResume(storagePath: storagePath, slug: slug)
        let url = resume.assetsDirectoryURL
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public func deleteResume(storagePath: String, slug: String) throws {
        let directory = try resumeDirectoryURL(storagePath: storagePath, slug: slug)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw ResumeStoreError.notFound(directory.path)
        }
        try fileManager.removeItem(at: directory)
    }

    // MARK: - Path helpers

    public static func resolvePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let resolved = URL(fileURLWithPath: expanded).resolvingSymlinksInPath().standardizedFileURL.path
        return resolved.hasSuffix("/") ? String(resolved.dropLast()) : resolved
    }

    public static func isPathAllowed(_ path: String, allowedDirectories: [String]) -> Bool {
        guard !allowedDirectories.isEmpty else { return true }
        let resolved = resolvePath(path)
        return allowedDirectories.contains { allowed in
            let normalized = resolvePath(allowed)
            return resolved == normalized || resolved.hasPrefix(normalized + "/")
        }
    }

    public static func validatedSlug(_ raw: String) throws -> String {
        let slug = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pattern = #"^[a-z0-9]+(?:-[a-z0-9]+)*$"#
        guard !slug.isEmpty, slug.range(of: pattern, options: .regularExpression) != nil else {
            throw ResumeStoreError.invalidSlug(raw)
        }
        return slug
    }

    // MARK: - Private

    private func readManifest(at url: URL) throws -> ResumeDocument {
        try decoder.decode(ResumeDocument.self, from: Data(contentsOf: url))
    }

    private func writeManifest(_ document: ResumeDocument, to directory: URL) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(document).write(
            to: directory.appendingPathComponent(Self.manifestFileName),
            options: .atomic
        )
    }
}
