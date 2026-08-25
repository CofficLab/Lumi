import Foundation

public enum AppStorePromoStoreError: LocalizedError, Equatable {
    case invalidStoragePath
    case invalidSlug(String)
    case alreadyExists(String)
    case notFound(String)
    case imageNotFound(String)
    case invalidLocale(String)
    case localeNotFound(String)
    case localeAlreadyExists(String)
    case invalidHTML([AppStorePromoLintIssue])
    case patchTextMissing(String)
    case patchTextNotUnique(String)
    case pathNotAllowed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidStoragePath: "Plugin storage path is missing or invalid."
        case .invalidSlug(let slug): "Invalid slug: \(slug)"
        case .alreadyExists(let path): "Item already exists at \(path)"
        case .notFound(let path): "Promotional task not found at \(path)"
        case .imageNotFound(let image): "Promotional image not found: \(image)"
        case .invalidLocale(let locale): "Invalid locale identifier: \(locale)"
        case .localeNotFound(let locale): "Promotional image locale not found: \(locale)"
        case .localeAlreadyExists(let locale): "Promotional image locale already exists: \(locale)"
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
    public static let imagesDirectoryName = "images"
    public static let assetsDirectoryName = "assets"
    public static let localizationsDirectoryName = "localizations"
    public static let defaultRelativeRoot = "tasks"

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

    public func rootURL(storagePath: String) throws -> URL {
        let resolved = Self.resolvePath(storagePath)
        guard !resolved.isEmpty else { throw AppStorePromoStoreError.invalidStoragePath }
        return URL(fileURLWithPath: resolved, isDirectory: true)
            .appendingPathComponent(relativeRoot, isDirectory: true)
    }

    public func taskDirectoryURL(storagePath: String, taskSlug: String) throws -> URL {
        let slug = try Self.validatedSlug(taskSlug)
        return try rootURL(storagePath: storagePath).appendingPathComponent(slug, isDirectory: true)
    }

    public func listTasks(storagePath: String) throws -> [AppStorePromoTask] {
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
    public func createTask(
        storagePath: String,
        slug: String,
        title: String,
        appName: String,
        deviceFamily: AppStorePromoDeviceFamily,
        localeIdentifier: String
    ) throws -> AppStorePromoTask {
        let normalized = try Self.validatedSlug(slug)
        let requestedLocale = localeIdentifier.isEmpty ? "en-US" : localeIdentifier
        guard let normalizedLocale = AppStorePromoLocale.normalize(requestedLocale) else {
            throw AppStorePromoStoreError.invalidLocale(localeIdentifier)
        }
        let directory = try taskDirectoryURL(storagePath: storagePath, taskSlug: normalized)
        guard !fileManager.fileExists(atPath: directory.path) else {
            throw AppStorePromoStoreError.alreadyExists(directory.path)
        }
        try fileManager.createDirectory(
            at: directory.appendingPathComponent(Self.imagesDirectoryName, isDirectory: true),
            withIntermediateDirectories: true
        )
        let task = AppStorePromoTask(
            id: normalized,
            title: title.isEmpty ? normalized : title,
            appName: appName,
            deviceFamily: deviceFamily,
            localeIdentifier: normalizedLocale
        )
        try writeManifest(task, to: directory)
        return task
    }

    public func readTask(storagePath: String, taskSlug: String) throws -> AppStorePromoTask {
        let directory = try taskDirectoryURL(storagePath: storagePath, taskSlug: taskSlug)
        let url = directory.appendingPathComponent(Self.manifestFileName)
        guard fileManager.fileExists(atPath: url.path) else { throw AppStorePromoStoreError.notFound(directory.path) }
        return try readManifest(at: url)
    }

    @discardableResult
    public func createImage(
        storagePath: String,
        taskSlug: String,
        imageSlug: String,
        title: String,
        html: String? = nil
    ) throws -> AppStorePromoResolvedImage {
        let normalizedImageSlug = try Self.validatedSlug(imageSlug)
        let taskDirectory = try taskDirectoryURL(storagePath: storagePath, taskSlug: taskSlug)
        var task = try readTask(storagePath: storagePath, taskSlug: taskSlug)
        let imageDirectory = taskDirectory
            .appendingPathComponent(Self.imagesDirectoryName, isDirectory: true)
            .appendingPathComponent(normalizedImageSlug, isDirectory: true)
        guard !fileManager.fileExists(atPath: imageDirectory.path),
              !task.images.contains(where: { $0.id == normalizedImageSlug }) else {
            throw AppStorePromoStoreError.alreadyExists(imageDirectory.path)
        }
        let resolvedHTML = html ?? AppStorePromoTemplateFactory.html(
            title: title.isEmpty ? normalizedImageSlug : title,
            appName: task.appName,
            family: task.deviceFamily
        )
        let report = linter.lint(html: resolvedHTML, documentDirectory: imageDirectory)
        guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }
        try fileManager.createDirectory(
            at: imageDirectory.appendingPathComponent(Self.assetsDirectoryName, isDirectory: true),
            withIntermediateDirectories: true
        )
        let now = Date()
        let image = AppStorePromoImage(
            id: normalizedImageSlug,
            title: title.isEmpty ? normalizedImageSlug : title,
            order: task.images.count,
            localeIdentifiers: [task.localeIdentifier],
            createdAt: now,
            updatedAt: now
        )
        try resolvedHTML.write(
            to: imageDirectory.appendingPathComponent(image.htmlFileName),
            atomically: true,
            encoding: .utf8
        )
        task.images.append(image)
        task.updatedAt = now
        try writeManifest(task, to: taskDirectory)
        return AppStorePromoResolvedImage(task: task, image: image, directoryURL: imageDirectory, html: resolvedHTML)
    }

    public func readImage(
        storagePath: String,
        taskSlug: String,
        imageSlug: String,
        localeIdentifier: String? = nil
    ) throws -> AppStorePromoResolvedImage {
        let taskDirectory = try taskDirectoryURL(storagePath: storagePath, taskSlug: taskSlug)
        let task = try readTask(storagePath: storagePath, taskSlug: taskSlug)
        guard let image = task.images.first(where: { $0.id == imageSlug }) else {
            throw AppStorePromoStoreError.imageNotFound(imageSlug)
        }
        let directory = taskDirectory
            .appendingPathComponent(Self.imagesDirectoryName, isDirectory: true)
            .appendingPathComponent(image.id, isDirectory: true)
        let resolvedLocale = try resolveLocale(localeIdentifier, image: image, task: task)
        let htmlURL = localizedHTMLURL(
            directory: directory,
            image: image,
            localeIdentifier: resolvedLocale
        )
        guard fileManager.fileExists(atPath: htmlURL.path) else { throw AppStorePromoStoreError.imageNotFound(imageSlug) }
        return AppStorePromoResolvedImage(
            task: task,
            image: image,
            directoryURL: directory,
            html: try String(contentsOf: htmlURL, encoding: .utf8),
            localeIdentifier: resolvedLocale,
            htmlURL: htmlURL
        )
    }

    @discardableResult
    public func addLocalization(
        _ localeIdentifier: String,
        copying sourceLocaleIdentifier: String? = nil,
        storagePath: String,
        taskSlug: String,
        imageSlug: String
    ) throws -> AppStorePromoResolvedImage {
        guard let normalizedLocale = AppStorePromoLocale.normalize(localeIdentifier) else {
            throw AppStorePromoStoreError.invalidLocale(localeIdentifier)
        }
        let taskDirectory = try taskDirectoryURL(storagePath: storagePath, taskSlug: taskSlug)
        var task = try readTask(storagePath: storagePath, taskSlug: taskSlug)
        guard let imageIndex = task.images.firstIndex(where: { $0.id == imageSlug }) else {
            throw AppStorePromoStoreError.imageNotFound(imageSlug)
        }
        let image = task.images[imageIndex]
        guard !image.localeIdentifiers.contains(where: { $0.caseInsensitiveCompare(normalizedLocale) == .orderedSame }) else {
            throw AppStorePromoStoreError.localeAlreadyExists(normalizedLocale)
        }

        let source = try readImage(
            storagePath: storagePath,
            taskSlug: taskSlug,
            imageSlug: imageSlug,
            localeIdentifier: sourceLocaleIdentifier
        )
        let destinationURL = localizedHTMLURL(
            directory: source.directoryURL,
            image: image,
            localeIdentifier: normalizedLocale
        )
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try source.html.write(to: destinationURL, atomically: true, encoding: .utf8)

        let now = Date()
        task.images[imageIndex].localeIdentifiers.append(normalizedLocale)
        task.images[imageIndex].updatedAt = now
        task.schemaVersion = AppStorePromoTask.currentSchemaVersion
        task.updatedAt = now
        try writeManifest(task, to: taskDirectory)
        return AppStorePromoResolvedImage(
            task: task,
            image: task.images[imageIndex],
            directoryURL: source.directoryURL,
            html: source.html,
            localeIdentifier: normalizedLocale,
            htmlURL: destinationURL
        )
    }

    @discardableResult
    public func replaceHTML(
        _ html: String,
        storagePath: String,
        taskSlug: String,
        imageSlug: String,
        localeIdentifier: String? = nil
    ) throws -> AppStorePromoResolvedImage {
        var resolved = try readImage(
            storagePath: storagePath,
            taskSlug: taskSlug,
            imageSlug: imageSlug,
            localeIdentifier: localeIdentifier
        )
        let report = linter.lint(html: html, documentDirectory: resolved.directoryURL)
        guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }
        try html.write(to: resolved.htmlURL, atomically: true, encoding: .utf8)

        var task = resolved.task
        guard let index = task.images.firstIndex(where: { $0.id == imageSlug }) else {
            throw AppStorePromoStoreError.imageNotFound(imageSlug)
        }
        let now = Date()
        task.images[index].updatedAt = now
        task.updatedAt = now
        try writeManifest(task, to: try taskDirectoryURL(storagePath: storagePath, taskSlug: taskSlug))
        resolved = AppStorePromoResolvedImage(
            task: task,
            image: task.images[index],
            directoryURL: resolved.directoryURL,
            html: html,
            localeIdentifier: resolved.localeIdentifier,
            htmlURL: resolved.htmlURL
        )
        return resolved
    }

    @discardableResult
    public func patchHTML(
        operations: [AppStorePromoPatchOperation],
        storagePath: String,
        taskSlug: String,
        imageSlug: String,
        localeIdentifier: String? = nil
    ) throws -> AppStorePromoResolvedImage {
        let current = try readImage(
            storagePath: storagePath,
            taskSlug: taskSlug,
            imageSlug: imageSlug,
            localeIdentifier: localeIdentifier
        )
        var candidate = current.html
        for operation in operations {
            let count = candidate.components(separatedBy: operation.oldText).count - 1
            guard count > 0 else { throw AppStorePromoStoreError.patchTextMissing(operation.oldText) }
            guard count == 1 else { throw AppStorePromoStoreError.patchTextNotUnique(operation.oldText) }
            candidate = candidate.replacingOccurrences(of: operation.oldText, with: operation.newText)
        }
        return try replaceHTML(
            candidate,
            storagePath: storagePath,
            taskSlug: taskSlug,
            imageSlug: imageSlug,
            localeIdentifier: current.localeIdentifier
        )
    }

    public func lintImage(
        storagePath: String,
        taskSlug: String,
        imageSlug: String,
        localeIdentifier: String? = nil
    ) throws -> AppStorePromoLintReport {
        let image = try readImage(
            storagePath: storagePath,
            taskSlug: taskSlug,
            imageSlug: imageSlug,
            localeIdentifier: localeIdentifier
        )
        return linter.lint(html: image.html, documentDirectory: image.directoryURL)
    }

    public func assetsDirectoryURL(storagePath: String, taskSlug: String, imageSlug: String) throws -> URL {
        let image = try readImage(storagePath: storagePath, taskSlug: taskSlug, imageSlug: imageSlug)
        let url = image.assetsDirectoryURL
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public func deleteTask(storagePath: String, taskSlug: String) throws {
        let directory = try taskDirectoryURL(storagePath: storagePath, taskSlug: taskSlug)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw AppStorePromoStoreError.notFound(directory.path)
        }
        try fileManager.removeItem(at: directory)
    }

    public func deleteImage(storagePath: String, taskSlug: String, imageSlug: String) throws {
        let taskDirectory = try taskDirectoryURL(storagePath: storagePath, taskSlug: taskSlug)
        var task = try readTask(storagePath: storagePath, taskSlug: taskSlug)
        guard let index = task.images.firstIndex(where: { $0.id == imageSlug }) else {
            throw AppStorePromoStoreError.imageNotFound(imageSlug)
        }
        let imageDirectory = taskDirectory
            .appendingPathComponent(Self.imagesDirectoryName, isDirectory: true)
            .appendingPathComponent(task.images[index].id, isDirectory: true)
        if fileManager.fileExists(atPath: imageDirectory.path) {
            try fileManager.removeItem(at: imageDirectory)
        }
        task.images.remove(at: index)
        for imageIndex in task.images.indices {
            task.images[imageIndex].order = imageIndex
        }
        task.updatedAt = Date()
        try writeManifest(task, to: taskDirectory)
    }

    public static func resolvePath(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
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
            throw AppStorePromoStoreError.invalidSlug(raw)
        }
        return slug
    }

    private func readManifest(at url: URL) throws -> AppStorePromoTask {
        var task = try decoder.decode(AppStorePromoTask.self, from: Data(contentsOf: url))
        for index in task.images.indices where task.images[index].localeIdentifiers.isEmpty {
            task.images[index].localeIdentifiers = [task.localeIdentifier]
        }
        return task
    }

    private func resolveLocale(
        _ requested: String?,
        image: AppStorePromoImage,
        task: AppStorePromoTask
    ) throws -> String {
        let available = image.localeIdentifiers.isEmpty ? [task.localeIdentifier] : image.localeIdentifiers
        guard let requested, !requested.isEmpty else { return available[0] }
        guard let normalized = AppStorePromoLocale.normalize(requested) else {
            throw AppStorePromoStoreError.invalidLocale(requested)
        }
        guard let match = available.first(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) else {
            throw AppStorePromoStoreError.localeNotFound(normalized)
        }
        return match
    }

    private func localizedHTMLURL(
        directory: URL,
        image: AppStorePromoImage,
        localeIdentifier: String
    ) -> URL {
        let primaryLocale = image.localeIdentifiers.first
        if primaryLocale == nil || primaryLocale == localeIdentifier {
            return directory.appendingPathComponent(image.htmlFileName)
        }
        return directory
            .appendingPathComponent(Self.localizationsDirectoryName, isDirectory: true)
            .appendingPathComponent("\(localeIdentifier).html")
    }

    private func writeManifest(_ task: AppStorePromoTask, to directory: URL) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(task).write(
            to: directory.appendingPathComponent(Self.manifestFileName),
            options: .atomic
        )
    }
}
