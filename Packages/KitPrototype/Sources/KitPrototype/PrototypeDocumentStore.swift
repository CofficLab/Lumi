import Foundation

// MARK: - 错误

public enum PrototypeStoreError: LocalizedError, Equatable {
    case invalidStoragePath
    case invalidSlug(String)
    case reservedSlug(String)
    case alreadyExists(String)
    case notFound(String)
    case screenNotFound(String)
    case invalidHTML([PrototypeLintIssue])
    case patchTextMissing(String)
    case patchTextNotUnique(String)
    case emptyScreenOrder
    case unknownScreenInOrder(String)
    case pathNotAllowed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidStoragePath: "Plugin storage path is missing or invalid."
        case .invalidSlug(let slug): "Invalid slug: \(slug). Use lowercase kebab-case."
        case .reservedSlug(let slug): "Reserved slug: \(slug)"
        case .alreadyExists(let path): "Item already exists at \(path)"
        case .notFound(let path): "Prototype project not found at \(path)"
        case .screenNotFound(let screen): "Screen not found: \(screen)"
        case .invalidHTML(let issues): "HTML validation failed: \(issues.map(\.message).joined(separator: " "))"
        case .patchTextMissing(let value): "Patch text was not found: \(value.prefix(80))"
        case .patchTextNotUnique(let value): "Patch text must occur exactly once: \(value.prefix(80))"
        case .emptyScreenOrder: "Screen order must list every screen exactly once."
        case .unknownScreenInOrder(let screen): "Screen order references an unknown screen: \(screen)"
        case .pathNotAllowed(let path): "Path is outside the allowed directories: \(path)"
        }
    }
}

// MARK: - 批量替换操作

public struct PrototypePatchOperation: Codable, Equatable, Sendable {
    public let oldText: String
    public let newText: String

    public init(oldText: String, newText: String) {
        self.oldText = oldText
        self.newText = newText
    }
}

// MARK: - 文档存储

/// 原型项目文档存取。
///
/// 磁盘布局（`storagePath` 即项目内 `.lumi/prototype`，本 store 再下探一层 `tasks/`）：
/// ```
/// tasks/<project-slug>/
///   manifest.json              ← PrototypeProject
///   assets/                    ← 项目级共享素材（屏幕用 ../assets/x.png 引用）
///   <screen-slug>/
///     index.html               ← 该屏完整 HTML
/// ```
///
/// 事实源只有一个：**HTML 是画面的唯一真相**，`manifest.json` 里的 `hotspots`
/// 是从 HTML 反向解析出的索引缓存，每次写入 HTML 时同步刷新。
public struct PrototypeDocumentStore: @unchecked Sendable {
    public static let manifestFileName = "manifest.json"
    public static let htmlFileName = "index.html"
    public static let assetsDirectoryName = "assets"
    public static let defaultRelativeRoot = "tasks"

    public let relativeRoot: String
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let linter: PrototypeHTMLLinter

    public init(
        relativeRoot: String = PrototypeDocumentStore.defaultRelativeRoot,
        fileManager: FileManager = .default,
        linter: PrototypeHTMLLinter = .init()
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

    // MARK: - 路径

    public func rootURL(storagePath: String) throws -> URL {
        let resolved = Self.resolvePath(storagePath)
        guard !resolved.isEmpty else { throw PrototypeStoreError.invalidStoragePath }
        return URL(fileURLWithPath: resolved, isDirectory: true)
            .appendingPathComponent(relativeRoot, isDirectory: true)
    }

    public func projectDirectoryURL(storagePath: String, projectSlug: String) throws -> URL {
        let slug = try Self.validatedSlug(projectSlug)
        return try rootURL(storagePath: storagePath).appendingPathComponent(slug, isDirectory: true)
    }

    /// 屏幕目录（`<project>/<screen-slug>`）。
    public func screenDirectoryURL(storagePath: String, projectSlug: String, screenSlug: String) throws -> URL {
        let normalized = try Self.validatedSlug(screenSlug)
        guard normalized != PrototypeHTMLAttributes.reservedSlug else {
            throw PrototypeStoreError.reservedSlug(screenSlug)
        }
        return try projectDirectoryURL(storagePath: storagePath, projectSlug: projectSlug)
            .appendingPathComponent(normalized, isDirectory: true)
    }

    /// 项目级共享素材目录，按需创建。
    public func assetsDirectoryURL(storagePath: String, projectSlug: String) throws -> URL {
        let url = try projectDirectoryURL(storagePath: storagePath, projectSlug: projectSlug)
            .appendingPathComponent(Self.assetsDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - 项目 CRUD

    public func listProjects(storagePath: String) throws -> [PrototypeProject] {
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
    public func createProject(
        storagePath: String,
        slug: String,
        title: String,
        style: PrototypeStyle,
        device: PrototypeDevice
    ) throws -> PrototypeProject {
        let normalized = try Self.validatedSlug(slug)
        let directory = try projectDirectoryURL(storagePath: storagePath, projectSlug: normalized)
        guard !fileManager.fileExists(atPath: directory.path) else {
            throw PrototypeStoreError.alreadyExists(directory.path)
        }
        try fileManager.createDirectory(
            at: directory.appendingPathComponent(Self.assetsDirectoryName, isDirectory: true),
            withIntermediateDirectories: true
        )
        let project = PrototypeProject(
            id: normalized,
            title: title.isEmpty ? normalized : title,
            style: style,
            device: device
        )
        try writeManifest(project, to: directory)
        return project
    }

    public func readProject(storagePath: String, projectSlug: String) throws -> PrototypeProject {
        let directory = try projectDirectoryURL(storagePath: storagePath, projectSlug: projectSlug)
        let url = directory.appendingPathComponent(Self.manifestFileName)
        guard fileManager.fileExists(atPath: url.path) else {
            throw PrototypeStoreError.notFound(directory.path)
        }
        return try readManifest(at: url)
    }

    @discardableResult
    public func renameProject(
        storagePath: String,
        projectSlug: String,
        title: String
    ) throws -> PrototypeProject {
        let directory = try projectDirectoryURL(storagePath: storagePath, projectSlug: projectSlug)
        var project = try readProject(storagePath: storagePath, projectSlug: projectSlug)
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return project }
        project.title = trimmed
        project.updatedAt = Date()
        try writeManifest(project, to: directory)
        return project
    }

    /// 更新画板设备。所有屏幕复用同一设备，因此只需改 manifest。
    @discardableResult
    public func updateDevice(
        storagePath: String,
        projectSlug: String,
        device: PrototypeDevice
    ) throws -> PrototypeProject {
        let directory = try projectDirectoryURL(storagePath: storagePath, projectSlug: projectSlug)
        var project = try readProject(storagePath: storagePath, projectSlug: projectSlug)
        project.device = device
        project.updatedAt = Date()
        try writeManifest(project, to: directory)
        return project
    }

    public func deleteProject(storagePath: String, projectSlug: String) throws {
        let directory = try projectDirectoryURL(storagePath: storagePath, projectSlug: projectSlug)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw PrototypeStoreError.notFound(directory.path)
        }
        try fileManager.removeItem(at: directory)
    }

    // MARK: - 屏幕 CRUD

    @discardableResult
    public func addScreen(
        storagePath: String,
        projectSlug: String,
        screenSlug: String,
        title: String,
        html: String? = nil
    ) throws -> PrototypeResolvedScreen {
        let normalized = try Self.validatedSlug(screenSlug)
        guard normalized != PrototypeHTMLAttributes.reservedSlug else {
            throw PrototypeStoreError.reservedSlug(screenSlug)
        }
        let projectDirectory = try projectDirectoryURL(storagePath: storagePath, projectSlug: projectSlug)
        let project = try readProject(storagePath: storagePath, projectSlug: projectSlug)
        let screenDirectory = projectDirectory.appendingPathComponent(normalized, isDirectory: true)
        guard !fileManager.fileExists(atPath: screenDirectory.path),
              !project.screens.contains(where: { $0.id == normalized }) else {
            throw PrototypeStoreError.alreadyExists(screenDirectory.path)
        }

        let resolvedHTML = html ?? PrototypeTemplateFactory.html(
            title: title.isEmpty ? normalized : title,
            appName: project.title,
            style: project.style,
            device: project.device
        )

        let now = Date()
        let screen = PrototypeScreen(
            id: normalized,
            title: title.isEmpty ? normalized : title,
            order: project.screens.count,
            hotspots: PrototypeHotspot.parse(fromHTML: resolvedHTML),
            createdAt: now,
            updatedAt: now
        )

        var candidateProject = project
        candidateProject.screens.append(screen)
        try validate(html: resolvedHTML, project: candidateProject, screen: screen, directory: screenDirectory)

        try fileManager.createDirectory(at: screenDirectory, withIntermediateDirectories: true)
        try resolvedHTML.write(
            to: screenDirectory.appendingPathComponent(screen.htmlFileName),
            atomically: true,
            encoding: .utf8
        )
        if candidateProject.startScreenID == nil {
            candidateProject.startScreenID = screen.id
        }
        candidateProject.updatedAt = now
        try writeManifest(candidateProject, to: projectDirectory)
        return PrototypeResolvedScreen(
            project: candidateProject,
            screen: screen,
            directoryURL: screenDirectory,
            html: resolvedHTML
        )
    }

    public func readScreen(
        storagePath: String,
        projectSlug: String,
        screenSlug: String
    ) throws -> PrototypeResolvedScreen {
        let projectDirectory = try projectDirectoryURL(storagePath: storagePath, projectSlug: projectSlug)
        let project = try readProject(storagePath: storagePath, projectSlug: projectSlug)
        guard let screen = project.screen(id: screenSlug) else {
            throw PrototypeStoreError.screenNotFound(screenSlug)
        }
        let directory = projectDirectory.appendingPathComponent(screen.id, isDirectory: true)
        let htmlURL = directory.appendingPathComponent(screen.htmlFileName)
        guard fileManager.fileExists(atPath: htmlURL.path) else {
            throw PrototypeStoreError.screenNotFound(screenSlug)
        }
        return PrototypeResolvedScreen(
            project: project,
            screen: screen,
            directoryURL: directory,
            html: try String(contentsOf: htmlURL, encoding: .utf8)
        )
    }

    /// 复制一屏（含 HTML；共享素材留在项目级 `assets/`，无需复制）。
    @discardableResult
    public func duplicateScreen(
        storagePath: String,
        projectSlug: String,
        screenSlug: String,
        newScreenSlug: String,
        title: String? = nil
    ) throws -> PrototypeResolvedScreen {
        let source = try readScreen(storagePath: storagePath, projectSlug: projectSlug, screenSlug: screenSlug)
        // 复制出的 HTML 里对旧屏的跳转仍然有效；对自身的跳转指向旧屏，属可接受起点。
        return try addScreen(
            storagePath: storagePath,
            projectSlug: projectSlug,
            screenSlug: newScreenSlug,
            title: title ?? source.screen.title,
            html: source.html
        )
    }

    public func deleteScreen(
        storagePath: String,
        projectSlug: String,
        screenSlug: String
    ) throws {
        let projectDirectory = try projectDirectoryURL(storagePath: storagePath, projectSlug: projectSlug)
        var project = try readProject(storagePath: storagePath, projectSlug: projectSlug)
        guard let index = project.screens.firstIndex(where: { $0.id == screenSlug }) else {
            throw PrototypeStoreError.screenNotFound(screenSlug)
        }
        let screenDirectory = projectDirectory.appendingPathComponent(project.screens[index].id, isDirectory: true)
        if fileManager.fileExists(atPath: screenDirectory.path) {
            try fileManager.removeItem(at: screenDirectory)
        }
        project.screens.remove(at: index)
        for screenIndex in project.screens.indices {
            project.screens[screenIndex].order = screenIndex
        }
        if project.startScreenID == screenSlug {
            project.startScreenID = project.sortedScreens.first?.id
        }
        project.updatedAt = Date()
        try writeManifest(project, to: projectDirectory)

        // 其余屏幕上指向被删屏幕的跳转现在悬空，刷新索引并提示（不阻断删除）。
        try refreshAllHotspots(storagePath: storagePath, projectSlug: projectSlug)
    }

    /// 重排屏幕顺序。`orderedScreenIDs` 必须恰好列出全部屏幕各一次。
    @discardableResult
    public func reorderScreens(
        storagePath: String,
        projectSlug: String,
        orderedScreenIDs: [String]
    ) throws -> PrototypeProject {
        let directory = try projectDirectoryURL(storagePath: storagePath, projectSlug: projectSlug)
        var project = try readProject(storagePath: storagePath, projectSlug: projectSlug)
        let existing = Set(project.screens.map(\.id))
        guard orderedScreenIDs.count == existing.count,
              Set(orderedScreenIDs) == existing else {
            if let unknown = orderedScreenIDs.first(where: { !existing.contains($0) }) {
                throw PrototypeStoreError.unknownScreenInOrder(unknown)
            }
            throw PrototypeStoreError.emptyScreenOrder
        }
        for (order, screenID) in orderedScreenIDs.enumerated() {
            guard let index = project.screens.firstIndex(where: { $0.id == screenID }) else { continue }
            project.screens[index].order = order
        }
        project.screens.sort { $0.order < $1.order }
        project.updatedAt = Date()
        try writeManifest(project, to: directory)
        return project
    }

    @discardableResult
    public func setStartScreen(
        storagePath: String,
        projectSlug: String,
        screenSlug: String
    ) throws -> PrototypeProject {
        let directory = try projectDirectoryURL(storagePath: storagePath, projectSlug: projectSlug)
        var project = try readProject(storagePath: storagePath, projectSlug: projectSlug)
        guard project.screen(id: screenSlug) != nil else {
            throw PrototypeStoreError.screenNotFound(screenSlug)
        }
        project.startScreenID = screenSlug
        project.updatedAt = Date()
        try writeManifest(project, to: directory)
        return project
    }

    // MARK: - HTML 编辑

    /// 校验并用完整 HTML 文档原子替换一屏。
    @discardableResult
    public func replaceScreenHTML(
        _ html: String,
        storagePath: String,
        projectSlug: String,
        screenSlug: String
    ) throws -> PrototypeResolvedScreen {
        var resolved = try readScreen(storagePath: storagePath, projectSlug: projectSlug, screenSlug: screenSlug)
        try validate(html: html, project: resolved.project, screen: resolved.screen, directory: resolved.directoryURL)
        try html.write(to: resolved.htmlURL, atomically: true, encoding: .utf8)

        let projectDirectory = try projectDirectoryURL(storagePath: storagePath, projectSlug: projectSlug)
        var project = resolved.project
        guard let index = project.screens.firstIndex(where: { $0.id == screenSlug }) else {
            throw PrototypeStoreError.screenNotFound(screenSlug)
        }
        let now = Date()
        project.screens[index].updatedAt = now
        project.screens[index].hotspots = PrototypeHotspot.parse(fromHTML: html)
        project.updatedAt = now
        try writeManifest(project, to: projectDirectory)

        resolved = PrototypeResolvedScreen(
            project: project,
            screen: project.screens[index],
            directoryURL: resolved.directoryURL,
            html: html
        )
        return resolved
    }

    /// 对一屏应用一批精确、唯一的文本替换（原子操作）。
    ///
    /// 任一条 `oldText` 缺失或出现多次即整体失败，不做部分应用。
    @discardableResult
    public func patchScreenHTML(
        operations: [PrototypePatchOperation],
        storagePath: String,
        projectSlug: String,
        screenSlug: String
    ) throws -> PrototypeResolvedScreen {
        let current = try readScreen(storagePath: storagePath, projectSlug: projectSlug, screenSlug: screenSlug)
        var candidate = current.html
        for operation in operations {
            let count = candidate.components(separatedBy: operation.oldText).count - 1
            guard count > 0 else { throw PrototypeStoreError.patchTextMissing(operation.oldText) }
            guard count == 1 else { throw PrototypeStoreError.patchTextNotUnique(operation.oldText) }
            candidate = candidate.replacingOccurrences(of: operation.oldText, with: operation.newText)
        }
        return try replaceScreenHTML(
            candidate,
            storagePath: storagePath,
            projectSlug: projectSlug,
            screenSlug: screenSlug
        )
    }

    // MARK: - 校验

    public func lintScreen(
        storagePath: String,
        projectSlug: String,
        screenSlug: String
    ) throws -> PrototypeLintReport {
        let resolved = try readScreen(storagePath: storagePath, projectSlug: projectSlug, screenSlug: screenSlug)
        return linter.lint(
            html: resolved.html,
            documentDirectory: resolved.directoryURL,
            knownScreenIDs: Set(resolved.project.screens.map(\.id))
        )
    }

    public func lintProject(
        storagePath: String,
        projectSlug: String
    ) throws -> [String: PrototypeLintReport] {
        let project = try readProject(storagePath: storagePath, projectSlug: projectSlug)
        var reports: [String: PrototypeLintReport] = [:]
        for screen in project.sortedScreens {
            reports[screen.id] = try lintScreen(
                storagePath: storagePath,
                projectSlug: projectSlug,
                screenSlug: screen.id
            )
        }
        return reports
    }

    private func validate(
        html: String,
        project: PrototypeProject,
        screen: PrototypeScreen,
        directory: URL
    ) throws {
        let report = linter.lint(
            html: html,
            documentDirectory: directory,
            knownScreenIDs: Set(project.screens.map(\.id))
        )
        guard report.isValid else { throw PrototypeStoreError.invalidHTML(report.errors) }
    }

    /// 重新解析所有屏幕的跳转索引并写回 manifest。
    private func refreshAllHotspots(storagePath: String, projectSlug: String) throws {
        let projectDirectory = try projectDirectoryURL(storagePath: storagePath, projectSlug: projectSlug)
        var project = try readProject(storagePath: storagePath, projectSlug: projectSlug)
        for index in project.screens.indices {
            let htmlURL = projectDirectory
                .appendingPathComponent(project.screens[index].id, isDirectory: true)
                .appendingPathComponent(project.screens[index].htmlFileName)
            guard let html = try? String(contentsOf: htmlURL, encoding: .utf8) else { continue }
            project.screens[index].hotspots = PrototypeHotspot.parse(fromHTML: html)
        }
        project.updatedAt = Date()
        try writeManifest(project, to: projectDirectory)
    }

    // MARK: - Manifest

    private func readManifest(at url: URL) throws -> PrototypeProject {
        var project = try decoder.decode(PrototypeProject.self, from: Data(contentsOf: url))
        project.screens.sort { $0.order < $1.order }
        for index in project.screens.indices {
            project.screens[index].order = index
        }
        return project
    }

    private func writeManifest(_ project: PrototypeProject, to directory: URL) throws {
        var normalized = project
        normalized.schemaVersion = PrototypeProject.currentSchemaVersion
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(normalized).write(
            to: directory.appendingPathComponent(Self.manifestFileName),
            options: .atomic
        )
    }

    // MARK: - 路径工具

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
            throw PrototypeStoreError.invalidSlug(raw)
        }
        return slug
    }
}
