import Foundation

public extension LumiPreviewFacade {
/// 编译策略：根据项目类型选择不同的编译路径。
enum BuildStrategy: Sendable, Equatable, Hashable {
    /// SPM Package：调用 `swift build --target`。
    case spm(packageDirectory: URL, targetName: String)

    /// Xcode 项目或 workspace：调用 `xcodebuild`。
    case xcode(projectURL: URL, scheme: String, configuration: String)

    /// 单文件增量编译：复用已提取的 Swift 编译命令。
    case incremental(fileURL: URL, compileCommand: String)
}

/// 编译规划器：分析项目结构，决定使用哪种编译策略。
///
/// SPM 优先：向上遍历文件系统查找 `Package.swift` 并解析 target。
/// 未找到 SPM 上下文时，再向上查找 `.xcworkspace` / `.xcodeproj`。
final class BuildPlanner: Sendable {

    /// 创建编译规划器。
    public init() {}

    // MARK: - 公开方法

    /// 根据文件路径推断编译策略。
    ///
    /// 从文件所在目录开始，优先查找 `Package.swift`。
    /// 找到后解析 manifest，匹配文件所属的 target。
    /// 未找到 SPM 上下文时，查找 `.xcworkspace` / `.xcodeproj`。
    /// 未找到时返回 `nil`。
    public func plan(for fileURL: URL) -> BuildStrategy? {
        if let packageDirectory = Self.findPackageDirectory(for: fileURL),
           let targetName = Self.resolveTargetName(for: fileURL, in: packageDirectory) {
            return .spm(packageDirectory: packageDirectory, targetName: targetName)
        }

        guard let projectURL = Self.findXcodeContainer(for: fileURL) else {
            return nil
        }

        return .xcode(
            projectURL: projectURL,
            scheme: Self.resolveSchemeName(for: projectURL),
            configuration: "Debug"
        )
    }

    // MARK: - 包目录查找

    /// 从文件所在目录开始向上遍历，查找 `Package.swift`。
    private static func findPackageDirectory(for fileURL: URL) -> URL? {
        let fileManager = FileManager.default

        // 确保从文件所在目录开始（而非文件自身）
        var currentDir = fileURL.deletingLastPathComponent()

        // 向上遍历，最多到根目录
        while currentDir.path != "/" && !currentDir.path.isEmpty {
            let packageSwiftURL = currentDir.appendingPathComponent("Package.swift")
            if fileManager.fileExists(atPath: packageSwiftURL.path) {
                return currentDir
            }
            let parentDir = currentDir.deletingLastPathComponent()
            if parentDir.path == currentDir.path {
                break
            }
            currentDir = parentDir
        }

        return nil
    }

    // MARK: - Xcode 项目查找

    /// 从文件所在目录开始向上遍历，查找 `.xcworkspace` 或 `.xcodeproj`。
    ///
    /// 同一目录下同时存在 workspace 和 project 时，优先使用 workspace，
    /// 这与多数 Xcode 项目的依赖解析入口一致。
    private static func findXcodeContainer(for fileURL: URL) -> URL? {
        var currentDir = fileURL.deletingLastPathComponent()

        while currentDir.path != "/" && !currentDir.path.isEmpty {
            if let workspace = firstContainer(in: currentDir, extensionName: "xcworkspace") {
                return workspace
            }
            if let project = firstContainer(in: currentDir, extensionName: "xcodeproj") {
                return project
            }

            let parentDir = currentDir.deletingLastPathComponent()
            if parentDir.path == currentDir.path {
                break
            }
            currentDir = parentDir
        }

        return nil
    }

    private static func firstContainer(in directory: URL, extensionName: String) -> URL? {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return entries
            .filter { $0.pathExtension == extensionName }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .first
    }

    private static func resolveSchemeName(for projectURL: URL) -> String {
        if let sharedScheme = firstSharedSchemeName(in: projectURL) {
            return sharedScheme
        }

        return projectURL.deletingPathExtension().lastPathComponent
    }

    private static func firstSharedSchemeName(in projectURL: URL) -> String? {
        let schemesDirectory = projectURL
            .appendingPathComponent("xcshareddata", isDirectory: true)
            .appendingPathComponent("xcschemes", isDirectory: true)

        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: schemesDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return entries
            .filter { $0.pathExtension == "xcscheme" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .first?
            .deletingPathExtension()
            .lastPathComponent
    }

    private static func schemeTargetName(scheme: String, projectURL: URL) -> String? {
        let schemeURL = projectURL
            .appendingPathComponent("xcshareddata", isDirectory: true)
            .appendingPathComponent("xcschemes", isDirectory: true)
            .appendingPathComponent("\(scheme).xcscheme")

        guard let content = try? String(contentsOf: schemeURL, encoding: .utf8) else {
            return nil
        }

        let pattern = /BlueprintName\s*=\s*"([^"]+)"/
        return content.firstMatch(of: pattern).map { String($0.1) }
    }

    private static func xcodeProjectURLs(for containerURL: URL) -> [URL] {
        if containerURL.pathExtension == "xcodeproj" {
            return [containerURL]
        }

        guard containerURL.pathExtension == "xcworkspace" else {
            return []
        }

        let workspaceContentURL = containerURL.appendingPathComponent("contents.xcworkspacedata")
        if let content = try? String(contentsOf: workspaceContentURL, encoding: .utf8) {
            let pattern = /location\s*=\s*"([^"]+\.xcodeproj)"/
            let projects = content.matches(of: pattern).compactMap { match -> URL? in
                let location = String(match.1)
                let normalizedLocation = location
                    .replacingOccurrences(of: "group:", with: "")
                    .replacingOccurrences(of: "container:", with: "")
                let url = URL(
                    fileURLWithPath: normalizedLocation,
                    relativeTo: containerURL.deletingLastPathComponent()
                ).standardizedFileURL
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }

            if !projects.isEmpty {
                return projects
            }
        }

        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: containerURL.deletingLastPathComponent(),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return entries
            .filter { $0.pathExtension == "xcodeproj" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Target 解析

    /// 解析 Package.swift，确定文件所属的 target name。
    ///
    /// 采用纯文本解析方式：先扫描 target 声明（名称和 path/sources），
    /// 再匹配文件路径。避免调用 `swift package describe` 带来的性能开销。
    private static func resolveTargetName(
        for fileURL: URL,
        in packageDirectory: URL
    ) -> String? {
        let packageSwiftPath = packageDirectory.appendingPathComponent("Package.swift").path
        guard let packageContent = try? String(contentsOfFile: packageSwiftPath, encoding: .utf8) else {
            return nil
        }

        let fileAbsPath = fileURL.standardizedFileURL.resolvingSymlinksInPath().path
        let pkgDir = packageDirectory.standardizedFileURL.resolvingSymlinksInPath().path

        // 提取所有 target 声明
        let targets = parseTargets(from: packageContent)

        // 优先匹配有明确 path/sources 的 target
        for target in targets {
            if matchesTarget(
                filePath: fileAbsPath,
                packageDir: pkgDir,
                target: target
            ) {
                return target.name
            }
        }

        return nil
    }

    static func swiftSourceFiles(packageDirectory: URL, targetName: String) -> [URL] {
        let packageSwiftPath = packageDirectory.appendingPathComponent("Package.swift").path
        guard let packageContent = try? String(contentsOfFile: packageSwiftPath, encoding: .utf8),
              let target = parseTargets(from: packageContent).first(where: { $0.name == targetName }) else {
            return []
        }

        let targetDirectory = resolvedTargetDirectory(packageDirectory: packageDirectory, target: target)
        let sourceRoots: [URL]
        if target.sources.isEmpty {
            sourceRoots = [targetDirectory]
        } else {
            sourceRoots = target.sources.map {
                URL(fileURLWithPath: $0, relativeTo: targetDirectory)
                    .standardizedFileURL
                    .resolvingSymlinksInPath()
            }
        }

        return swiftSourceFiles(in: sourceRoots)
    }

    static func swiftSourceFiles(projectURL: URL, scheme: String, containing fileURL: URL) -> [URL] {
        let currentSourceURL = fileURL.standardizedFileURL.resolvingSymlinksInPath()

        for candidateProjectURL in xcodeProjectURLs(for: projectURL) {
            guard let project = XcodeProjectSourceIndex(projectURL: candidateProjectURL) else {
                continue
            }

            let targetName = schemeTargetName(scheme: scheme, projectURL: candidateProjectURL) ?? scheme
            let schemeSources = project.swiftSourceFiles(targetName: targetName)
            if !schemeSources.isEmpty {
                return augmentedXcodeSources(schemeSources, containing: currentSourceURL)
            }

            if let containingSources = project.swiftSourceFiles(containing: currentSourceURL) {
                return augmentedXcodeSources(containingSources, containing: currentSourceURL)
            }
        }

        return swiftSourceFiles(in: [currentSourceURL.deletingLastPathComponent()])
    }

    private static func augmentedXcodeSources(_ sources: [URL], containing fileURL: URL) -> [URL] {
        let siblingSources = swiftSourceFiles(in: [fileURL.deletingLastPathComponent()])
        return (sources + siblingSources)
            .map { $0.standardizedFileURL.resolvingSymlinksInPath() }
            .uniqued()
            .sorted { $0.path < $1.path }
    }

    /// 解析出的 target 信息
    private struct TargetInfo {
        enum Kind {
            case regular
            case executable
            case test
        }

        let kind: Kind
        let name: String
        let path: String?
        let sources: [String]
    }

    /// 从 Package.swift 内容中提取 target 信息。
    ///
    /// 使用轻量级文本解析匹配 `.target(...)`、`.executableTarget(...)` 和 `.testTarget(...)` 声明。
    private static func parseTargets(from content: String) -> [TargetInfo] {
        var targets: [TargetInfo] = []

        let namePattern = /name:\s*"([^"]+)"/
        let pathPattern = /path:\s*"([^"]+)"/
        let sourcesPattern = /(?:^|[^a-zA-Z])sources:\s*\[([^\]]*)\]/
        let characters = Array(content)

        for declaration in targetDeclarations(in: characters) {
            let body = String(characters[declaration.bodyRange])

            guard let nameMatch = body.firstMatch(of: namePattern) else { continue }
            let name = String(nameMatch.1)

            let path = body.firstMatch(of: pathPattern).map { String($0.1) }

            var sources: [String] = []
            if let sourcesMatch = body.firstMatch(of: sourcesPattern) {
                let sourcesBody = String(sourcesMatch.1)
                let sourceItemPattern = /"([^"]+)"/
                for sourceMatch in sourcesBody.matches(of: sourceItemPattern) {
                    sources.append(String(sourceMatch.1))
                }
            }

            targets.append(TargetInfo(kind: declaration.kind, name: name, path: path, sources: sources))
        }

        return targets
    }

    private static func targetDeclarations(
        in characters: [Character]
    ) -> [(kind: TargetInfo.Kind, bodyRange: Range<Int>)] {
        let starters: [(text: String, kind: TargetInfo.Kind)] = [
            (".executableTarget(", .executable),
            (".testTarget(", .test),
            (".target(", .regular)
        ]

        var declarations: [(kind: TargetInfo.Kind, bodyRange: Range<Int>)] = []
        var offset = 0

        while offset < characters.count {
            guard let starter = starters.first(where: { matches(Array($0.text), at: offset, in: characters) }) else {
                offset += 1
                continue
            }

            let openingParenOffset = offset + starter.text.count - 1
            guard let closingParenOffset = closingParenOffset(
                from: openingParenOffset,
                in: characters
            ) else {
                offset += starter.text.count
                continue
            }

            declarations.append((
                kind: starter.kind,
                bodyRange: (openingParenOffset + 1)..<closingParenOffset
            ))
            offset = closingParenOffset + 1
        }

        return declarations
    }

    private static func closingParenOffset(from openingParenOffset: Int, in characters: [Character]) -> Int? {
        var depth = 0
        var offset = openingParenOffset
        var inString = false
        var isEscaped = false

        while offset < characters.count {
            let character = characters[offset]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
                offset += 1
                continue
            }

            if character == "\"" {
                inString = true
            } else if character == "(" {
                depth += 1
            } else if character == ")" {
                depth -= 1
                if depth == 0 {
                    return offset
                }
            }

            offset += 1
        }

        return nil
    }

    private static func matches(_ needle: [Character], at offset: Int, in characters: [Character]) -> Bool {
        guard offset + needle.count <= characters.count else { return false }
        for needleOffset in needle.indices where characters[offset + needleOffset] != needle[needleOffset] {
            return false
        }
        return true
    }

    /// 判断文件路径是否属于指定 target。
    private static func matchesTarget(
        filePath: String,
        packageDir: String,
        target: TargetInfo
    ) -> Bool {
        let resolvedDir = resolvedTargetDirectory(
            packageDirectory: URL(fileURLWithPath: packageDir),
            target: target
        ).path
        guard filePath == resolvedDir || filePath.hasPrefix(resolvedDir + "/") else {
            return false
        }

        guard !target.sources.isEmpty else {
            return true
        }

        return target.sources.contains { source in
            let absoluteSource = URL(fileURLWithPath: source, relativeTo: URL(fileURLWithPath: resolvedDir))
                .standardizedFileURL
                .path
            return filePath == absoluteSource || filePath.hasPrefix(absoluteSource + "/")
        }
    }

    private static func resolvedTargetDirectory(packageDirectory: URL, target: TargetInfo) -> URL {
        let effectivePath = target.path ?? defaultPath(for: target)

        if effectivePath.hasPrefix("/") {
            return URL(fileURLWithPath: effectivePath)
                .standardizedFileURL
                .resolvingSymlinksInPath()
        }

        return packageDirectory
            .appendingPathComponent(effectivePath, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
    }

    static func swiftSourceFiles(in roots: [URL], excluding excludedRoots: [URL] = []) -> [URL] {
        var files: Set<URL> = []
        let fileManager = FileManager.default
        let excludedPaths = excludedRoots
            .map { $0.standardizedFileURL.resolvingSymlinksInPath().path }

        for root in roots {
            if isExcluded(root, by: excludedPaths) {
                continue
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory) else {
                continue
            }

            if !isDirectory.boolValue {
                if isCompilableSwiftSource(root) {
                    files.insert(root.standardizedFileURL.resolvingSymlinksInPath())
                }
                continue
            }

            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                if isExcluded(fileURL, by: excludedPaths) {
                    // Only call skipDescendants() for directories.
                    // Calling it on a regular file can cause the enumerator
                    // to skip subsequent sibling directories on macOS.
                    let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
                    if values?.isDirectory == true {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                guard isCompilableSwiftSource(fileURL) else {
                    continue
                }

                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if values?.isRegularFile == true {
                    files.insert(fileURL.standardizedFileURL.resolvingSymlinksInPath())
                }
            }
        }

        return files.sorted { $0.path < $1.path }
    }

    static func isExcluded(_ url: URL, by excludedPaths: [String]) -> Bool {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        return excludedPaths.contains { excludedPath in
            path == excludedPath || path.hasPrefix(excludedPath + "/")
        }
    }

    private static func isCompilableSwiftSource(_ url: URL) -> Bool {
        url.pathExtension == "swift" && url.lastPathComponent != "Package.swift"
    }

    private static func defaultPath(for target: TargetInfo) -> String {
        switch target.kind {
        case .regular, .executable:
            "Sources/\(target.name)"
        case .test:
            "Tests/\(target.name)"
        }
    }
}

private struct XcodeProjectSourceIndex {
    private struct Object {
        let id: String
        let body: String

        var isa: String? {
            field("isa")
        }

        func field(_ name: String) -> String? {
            guard let range = body.range(of: "\(name) =") else {
                return nil
            }

            let valueStart = range.upperBound
            guard let valueEnd = body[valueStart...].firstIndex(of: ";") else {
                return nil
            }

            return String(body[valueStart..<valueEnd])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .removingPBXComment()
                .removingPBXQuotes()
        }

        func listField(_ name: String) -> [String] {
            guard let range = body.range(of: "\(name) = (") else {
                return []
            }

            let listStart = range.upperBound
            guard let listEnd = body[listStart...].range(of: ");")?.lowerBound else {
                return []
            }

            let listBody = String(body[listStart..<listEnd])
            let pattern = /([A-Za-z0-9]{8,})/
            return listBody.matches(of: pattern).map { String($0.1) }
        }

        func stringListField(_ name: String) -> [String] {
            guard let range = body.range(of: "\(name) = (") else {
                return []
            }

            let listStart = range.upperBound
            guard let listEnd = body[listStart...].range(of: ");")?.lowerBound else {
                return []
            }

            let listBody = String(body[listStart..<listEnd])
            return listBody
                .split(separator: ",")
                .map(String.init)
                .map { $0.removingPBXComment().removingPBXQuotes() }
                .filter { !$0.isEmpty }
        }
    }

    private let projectDirectory: URL
    private let objects: [String: Object]
    private let parentGroupByChildID: [String: String]

    init?(projectURL: URL) {
        let projectFileURL = projectURL.appendingPathComponent("project.pbxproj")
        guard let content = try? String(contentsOf: projectFileURL, encoding: .utf8) else {
            return nil
        }

        let objects = Self.parseObjects(from: content)
        self.projectDirectory = projectURL.deletingLastPathComponent()
        self.objects = Dictionary(uniqueKeysWithValues: objects.map { ($0.id, $0) })

        var parentGroupByChildID: [String: String] = [:]
        for object in objects where object.isa == "PBXGroup"
            || object.isa == "PBXVariantGroup"
            || object.isa == "PBXFileSystemSynchronizedRootGroup" {
            for childID in object.listField("children") {
                parentGroupByChildID[childID] = object.id
            }
        }
        self.parentGroupByChildID = parentGroupByChildID
    }

    func swiftSourceFiles(targetName: String) -> [URL] {
        guard let target = objects.values.first(where: { object in
            object.isa == "PBXNativeTarget" && object.field("name") == targetName
        }) else {
            return []
        }

        return swiftSourceFiles(target: target)
    }

    func swiftSourceFiles(containing fileURL: URL) -> [URL]? {
        let currentSourceURL = fileURL.standardizedFileURL.resolvingSymlinksInPath()
        for target in objects.values where target.isa == "PBXNativeTarget" {
            let sources = swiftSourceFiles(target: target)
            if sources.contains(currentSourceURL) {
                return sources
            }
        }

        return nil
    }

    private func swiftSourceFiles(target: Object) -> [URL] {
        let sourcePhaseIDs = target.listField("buildPhases").filter {
            objects[$0]?.isa == "PBXSourcesBuildPhase"
        }

        let fileRefIDs = sourcePhaseIDs
            .compactMap { objects[$0] }
            .flatMap { $0.listField("files") }
            .compactMap { objects[$0]?.field("fileRef") }

        let explicitSources = fileRefIDs
            .compactMap { sourceURL(fileRefID: $0) }
            .filter { $0.pathExtension == "swift" }
            .map { $0.standardizedFileURL.resolvingSymlinksInPath() }

        let synchronizedSources = target
            .listField("fileSystemSynchronizedGroups")
            .flatMap { synchronizedSourceFiles(rootGroupID: $0, targetID: target.id) }

        return (explicitSources + synchronizedSources)
            .uniqued()
            .sorted { $0.path < $1.path }
    }

    private func synchronizedSourceFiles(rootGroupID: String, targetID: String) -> [URL] {
        guard let rootGroup = objects[rootGroupID],
              rootGroup.isa == "PBXFileSystemSynchronizedRootGroup" else {
            return []
        }

        let rootURL = groupBaseURL(groupID: rootGroupID)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        let excludedURLs = rootGroup
            .listField("exceptions")
            .compactMap { objects[$0] }
            .filter { exception in
                guard let exceptionTargetID = exception.field("target") else {
                    return true
                }
                return exceptionTargetID == targetID
            }
            .flatMap { exception in
                exception.stringListField("membershipExceptions").map { relativePath in
                    rootURL
                        .appendingPathComponent(relativePath)
                        .standardizedFileURL
                        .resolvingSymlinksInPath()
                }
            }

        return BuildPlanner.swiftSourceFiles(in: [rootURL], excluding: excludedURLs)
    }

    private func sourceURL(fileRefID: String) -> URL? {
        guard let fileRef = objects[fileRefID],
              fileRef.isa == "PBXFileReference" else {
            return nil
        }

        let path = fileRef.field("path") ?? fileRef.field("name")
        guard let path, !path.isEmpty else {
            return nil
        }

        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }

        if fileRef.field("sourceTree") == "SOURCE_ROOT" {
            return projectDirectory.appendingPathComponent(path)
        }

        let parentBaseURL = parentGroupByChildID[fileRefID]
            .flatMap { groupBaseURL(groupID: $0) } ?? projectDirectory
        return parentBaseURL.appendingPathComponent(path)
    }

    private func groupBaseURL(groupID: String) -> URL {
        guard let group = objects[groupID] else {
            return projectDirectory
        }

        let parentBaseURL = parentGroupByChildID[groupID]
            .flatMap { self.groupBaseURL(groupID: $0) } ?? projectDirectory

        guard let path = group.field("path"),
              !path.isEmpty else {
            return parentBaseURL
        }

        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }

        if group.field("sourceTree") == "SOURCE_ROOT" {
            return projectDirectory.appendingPathComponent(path)
        }

        return parentBaseURL.appendingPathComponent(path)
    }

    private static func parseObjects(from content: String) -> [Object] {
        var objects: [Object] = []
        let startPattern = /^\s*([A-Fa-f0-9]{8,})(?:\s*\/\*[^*]*\*\/)?\s*=\s*\{(.*)$/
        var activeID: String?
        var activeBody: [String] = []
        var depth = 0

        for line in content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if activeID != nil {
                activeBody.append(line)
                depth += braceDepthDelta(in: line)
                if depth <= 0 {
                    objects.append(Object(id: activeID!, body: activeBody.joined(separator: "\n")))
                    activeID = nil
                    activeBody = []
                    depth = 0
                }
                continue
            }

            guard let match = line.firstMatch(of: startPattern) else {
                continue
            }

            let id = String(match.1)
            activeID = id
            activeBody = [String(match.2)]
            depth = 1 + braceDepthDelta(in: String(match.2))
            if depth <= 0 {
                objects.append(Object(id: id, body: activeBody.joined(separator: "\n")))
                activeID = nil
                activeBody = []
                depth = 0
            }
        }

        return objects
    }

    private static func braceDepthDelta(in line: String) -> Int {
        line.reduce(0) { result, character in
            if character == "{" {
                return result + 1
            }
            if character == "}" {
                return result - 1
            }
            return result
        }
    }
}

}

private extension String {
    func removingPBXComment() -> String {
        let pattern = /\/\*.*?\*\//
        return replacing(pattern, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func removingPBXQuotes() -> String {
        guard hasPrefix("\""), hasSuffix("\""), count >= 2 else {
            return self
        }

        return String(dropFirst().dropLast())
    }
}

private extension Array where Element == URL {
    func uniqued() -> [URL] {
        var seen: Set<String> = []
        var result: [URL] = []
        for url in self {
            if seen.insert(url.path).inserted {
                result.append(url)
            }
        }
        return result
    }
}
