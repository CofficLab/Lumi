import Foundation
import os
import SuperLogKit

/// Xcode 项目解析器：发现并解析 .xcodeproj / .xcworkspace
final public class XcodeProjectResolver: SuperLog, @unchecked Sendable {

    public static let emoji = "🔍"
    public static let verbose = false

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode.resolver")

    struct CapturedProcessDataResult: Sendable, Equatable {
        let terminationStatus: Int32
        let stdout: Data
    }

    public init() {}

    // MARK: - 项目发现

    /// 在指定目录中查找 .xcworkspace，找到第一个
    public static func findWorkspace(in directory: URL) -> URL? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }
        // 优先返回 .xcworkspace
        if let workspace = contents.first(where: { $0.pathExtension == "xcworkspace" }) {
            return workspace
        }
        // 其次返回 .xcodeproj
        return contents.first(where: { $0.pathExtension == "xcodeproj" })
    }

    /// 判断一个目录是否是 Xcode 项目根目录
    public static func isXcodeProjectRoot(_ directory: URL) -> Bool {
        findWorkspace(in: directory) != nil
    }

    /// 从 `.xcscheme` 文件快速发现 scheme 名称。
    public static func discoverSchemeNames(at projectLikeURL: URL) -> [String] {
        XcodeSchemeDiscovery.discoverSchemeNames(at: projectLikeURL)
    }

    // MARK: - 项目解析

    public typealias ResolutionProgressHandler = @Sendable (BuildContextResolutionProgress.Update) -> Void

    /// 解析一个 workspace / project，返回完整的上下文
    /// 此方法会调用 xcodebuild -list -json 获取结构化数据
    public func resolve(
        workspaceURL: URL,
        onProgress: ResolutionProgressHandler? = nil
    ) async -> XcodeWorkspaceContext? {
        let isProject = workspaceURL.pathExtension == "xcodeproj"
        let isWorkspace = workspaceURL.pathExtension == "xcworkspace"
        guard isProject || isWorkspace else {
            if Self.verbose {
                            Self.logger.warning("\(Self.t)无效的项目路径: \(workspaceURL.path, privacy: .public)")
            }
            return nil
        }

        let name = workspaceURL.deletingPathExtension().lastPathComponent
        let projectPath = isProject ? workspaceURL : nil
        let workspacePath = isWorkspace ? workspaceURL : nil

        onProgress?(.init(
            phase: .runningXcodebuildList,
            detail: workspaceURL.lastPathComponent
        ))

        // 获取 xcodebuild -list -json 输出
        guard let listResult = await fetchBuildList(workspaceURL: workspacePath, projectURL: projectPath) else {
            if Self.verbose {
                            Self.logger.error("\(Self.t)无法获取构建列表: \(workspaceURL.path, privacy: .public)")
            }
            return nil
        }

        let schemes = (listResult.workspace?.schemes ?? []) + (listResult.project?.schemes ?? [])
        let uniqueSchemes = Self.uniquePreservingOrder(schemes)

        // 解析 targets。pbxproj 解析和目录枚举可能很重，放到后台执行。
        let targetNames = listResult.project?.targets ?? []
        let configurations = listResult.project?.configurations ?? []
        let projectLikePath = workspaceURL.path
        let scanProgressHandler: (@Sendable (String) -> Void)? = {
            guard let onProgress else { return nil }
            return { path in
                onProgress(.init(
                    phase: .parsingProjectMembership,
                    currentItem: URL(fileURLWithPath: path).lastPathComponent
                ))
            }
        }()
        let resolvedProjectURL = Self.projectURL(for: URL(fileURLWithPath: projectLikePath))
        let targetSourceFiles: [String: Set<String>]
        let targetProductTypes: [String: String]
        (targetSourceFiles, targetProductTypes) = await Task.detached(priority: .userInitiated) { @Sendable in
            let sourceFiles = Self.resolveTargetSourceFiles(
                projectLikeURL: URL(fileURLWithPath: projectLikePath),
                onScanProgress: scanProgressHandler
            )
            let productTypes = resolvedProjectURL.map { XcodePBXProjParser.parseTargetProductTypes(projectURL: $0) } ?? [:]
            return (sourceFiles, productTypes)
        }.value

        let targetContexts = targetNames.map { targetName in
            let targetConfigurations = configurations.map { configName in
                XcodeBuildConfigurationContext(id: "\(targetName)_\(configName)", name: configName)
            }
            return XcodeTargetContext(
                id: targetName,
                name: targetName,
                productType: targetProductTypes[targetName],
                buildConfigurations: targetConfigurations,
                sourceFiles: targetSourceFiles[targetName] ?? []
            )
        }

        let projectContext = XcodeProjectContext(
            id: workspaceURL.path,
            name: name,
            path: workspaceURL,
            targets: targetContexts,
            buildConfigurations: configurations.map {
                XcodeBuildConfigurationContext(id: $0, name: $0)
            },
            schemes: uniqueSchemes.map {
                XcodeSchemeContext(
                    id: $0,
                    name: $0,
                    buildableTargets: targetNames,
                    defaultConfiguration: configurations.first,
                    activeConfiguration: configurations.first ?? "Debug"
                )
            }
        )

        let workspaceContext = XcodeWorkspaceContext(
            id: workspaceURL.path,
            name: name,
            path: workspaceURL,
            projects: [projectContext],
            schemes: uniqueSchemes.map {
                XcodeSchemeContext(
                    id: $0,
                    name: $0,
                    buildableTargets: targetNames,
                    defaultConfiguration: configurations.first,
                    activeConfiguration: configurations.first ?? "Debug"
                )
            },
            activeScheme: nil
        )

        return workspaceContext
    }

    /// 基于 `.xcscheme` 文件构建占位 workspace，供 UI 在 `xcodebuild -list` 完成前快速展示。
    static func makePlaceholderWorkspaceContext(
        workspaceURL: URL,
        schemeNames: [String],
        targetSourceFiles: [String: Set<String>] = [:]
    ) -> XcodeWorkspaceContext {
        let name = workspaceURL.deletingPathExtension().lastPathComponent
        let uniqueSchemes = uniquePreservingOrder(schemeNames)
        let targetNames = targetSourceFiles.keys.sorted()
        let buildableTargets = targetNames.isEmpty ? uniqueSchemes : targetNames
        let schemeContexts = uniqueSchemes.map { schemeName in
            XcodeSchemeContext(
                id: schemeName,
                name: schemeName,
                buildableTargets: buildableTargets,
                defaultConfiguration: "Debug",
                activeConfiguration: "Debug"
            )
        }
        let defaultConfigurations = [
            XcodeBuildConfigurationContext(id: "Debug", name: "Debug"),
            XcodeBuildConfigurationContext(id: "Release", name: "Release"),
        ]
        let targetProductTypes = Self.projectURL(for: workspaceURL)
            .map { XcodePBXProjParser.parseTargetProductTypes(projectURL: $0) } ?? [:]
        let targets = targetNames.map { targetName in
            XcodeTargetContext(
                id: targetName,
                name: targetName,
                productType: targetProductTypes[targetName],
                buildConfigurations: defaultConfigurations,
                sourceFiles: targetSourceFiles[targetName] ?? []
            )
        }
        let projectContext = XcodeProjectContext(
            id: workspaceURL.path,
            name: name,
            path: workspaceURL,
            targets: targets,
            buildConfigurations: defaultConfigurations,
            schemes: schemeContexts
        )
        return XcodeWorkspaceContext(
            id: workspaceURL.path,
            name: name,
            path: workspaceURL,
            projects: [projectContext],
            schemes: schemeContexts,
            activeScheme: nil
        )
    }

    /// 解析 scheme 列表
    public func resolveSchemes(workspaceURL: URL, projectURL: URL?) async -> [XcodeSchemeContext] {
        guard let listResult = await fetchBuildList(workspaceURL: workspaceURL, projectURL: projectURL) else {
            return []
        }

        let schemeNames = (listResult.workspace?.schemes ?? []) + (listResult.project?.schemes ?? [])
        let uniqueSchemes = Self.uniquePreservingOrder(schemeNames)
        let targetNames = listResult.project?.targets ?? []
        let configurations = listResult.project?.configurations ?? []

        return uniqueSchemes.map {
            XcodeSchemeContext(
                id: $0,
                name: $0,
                buildableTargets: targetNames,
                defaultConfiguration: configurations.first,
                activeConfiguration: configurations.first ?? "Debug"
            )
        }
    }

    // MARK: - xcodebuild 调用

    /// 执行 `xcodebuild -list -json`
    private func fetchBuildList(workspaceURL: URL?, projectURL: URL?) async -> XcodeBuildSettingsParser.ListResult? {
        var args = ["-list", "-json"]

        if let workspaceURL {
            args += ["-workspace", workspaceURL.path]
        } else if let projectURL {
            args += ["-project", projectURL.path]
        }

        guard let data = await runXcodeBuild(args: args) else { return nil }

        do {
            return try XcodeBuildSettingsParser.parseListOutput(data)
        } catch {
            if Self.verbose {
                            Self.logger.error("\(Self.t)解析构建列表失败: \(error.localizedDescription, privacy: .public)")
            }
            return nil
        }
    }

    /// 执行 `xcodebuild -showBuildSettings -json`
    public func fetchBuildSettings(workspaceURL: URL?, projectURL: URL?, scheme: String, configuration: String? = nil, destination: String? = nil) async -> [[String: String]]? {
        var args = ["-showBuildSettings", "-json"]

        if let workspaceURL {
            args += ["-workspace", workspaceURL.path]
        } else if let projectURL {
            args += ["-project", projectURL.path]
        }

        args += ["-scheme", scheme]

        if let configuration, !configuration.isEmpty {
            args += ["-configuration", configuration]
        }

        if let destination {
            args += ["-destination", destination]
        }

        guard let data = await runXcodeBuild(args: args) else { return nil }

        do {
            return try XcodeBuildSettingsParser.parseBuildSettingsOutput(data)
        } catch {
            if Self.verbose {
                            Self.logger.error("\(Self.t)解析构建设置失败: \(error.localizedDescription, privacy: .public)")
            }
            return nil
        }
    }

    // MARK: - 工具方法

    static func resolveTargetSourceFiles(
        projectLikeURL: URL,
        onScanProgress: (@Sendable (String) -> Void)? = nil
    ) -> [String: Set<String>] {
        guard let projectURL = projectURL(for: projectLikeURL) else {
            return [:]
        }

        let projectRoot = projectURL.deletingLastPathComponent()
        var result: [String: Set<String>] = [:]
        if let graph = try? XcodePBXProjParser.parseMembershipGraph(projectURL: projectURL) {
            result = graph.targetRoots.reduce(into: [String: Set<String>]()) { result, item in
            let files = item.value.reduce(into: Set<String>()) { partial, root in
                let rootURL: URL
                if root.rootPath.hasPrefix("/") {
                    rootURL = URL(filePath: root.rootPath)
                } else {
                    rootURL = projectRoot.appendingPathComponent(root.rootPath)
                }
                partial.formUnion(
                    XcodeProjectFileEnumerator.enumerateFiles(
                        in: rootURL,
                        excluding: root.excludedRelativePaths,
                        onScanProgress: onScanProgress
                    )
                )
            }
            result[item.key] = files
            }
        } else if Self.verbose {
            Self.logger.warning("\(Self.t)无法解析 pbxproj 文件归属: \(projectURL.path, privacy: .public)")
        }

        let swiftPackageFiles = XcodeSwiftPackageSourceResolver.resolveTargetSourceFiles(
            projectURL: projectURL,
            onScanProgress: onScanProgress
        )
        for (targetName, files) in swiftPackageFiles {
            result[targetName, default: []].formUnion(files)
        }
        return result
    }

    static func projectURL(for projectLikeURL: URL) -> URL? {
        if projectLikeURL.pathExtension == "xcodeproj" {
            return projectLikeURL
        }

        let directoryURL = projectLikeURL.deletingLastPathComponent()
        let preferredCandidate = directoryURL.appendingPathComponent(
            projectLikeURL.deletingPathExtension().lastPathComponent + ".xcodeproj"
        )
        if FileManager.default.fileExists(atPath: preferredCandidate.path) {
            return preferredCandidate
        }
        if let fallbackCandidate = try? FileManager.default
            .contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "xcodeproj" }) {
            return fallbackCandidate
        }
        return nil
    }

    public static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }

    static func path(_ fileURL: URL, relativeTo rootURL: URL) -> String {
        let filePath = normalizedPath(fileURL.path)
        let rootPath = normalizedPath(rootURL.path)
        guard !filePath.isEmpty, !rootPath.isEmpty else { return fileURL.lastPathComponent }

        let rootPrefix = rootPath == "/" ? "/" : rootPath + "/"
        guard filePath.hasPrefix(rootPrefix) else { return fileURL.lastPathComponent }
        return String(filePath.dropFirst(rootPrefix.count))
    }

    /// Canonical path used when matching files to target membership.
    static func normalizedMembershipPath(for fileURL: URL) -> String {
        normalizedMembershipPath(fileURL.resolvingSymlinksInPath().path)
    }

    static func normalizedMembershipPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let resolved = URL(fileURLWithPath: trimmed).resolvingSymlinksInPath().path
        return resolved != "/" && resolved.hasSuffix("/") ? String(resolved.dropLast()) : resolved
    }

    static func targetMembershipContains(fileURL: URL, sourceFiles: some Collection<String>) -> Bool {
        let lookupPath = normalizedMembershipPath(for: fileURL)
        return sourceFiles.contains { normalizedMembershipPath($0) == lookupPath }
    }

    private static func normalizedPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let standardized = URL(fileURLWithPath: trimmed).standardizedFileURL.path
        return standardized != "/" && standardized.hasSuffix("/") ? String(standardized.dropLast()) : standardized
    }

    /// 异步执行 xcodebuild
    private func runXcodeBuild(args: [String]) async -> Data? {
        do {
            let result = try await Self.runProcessCapturingStdout(
                executableURL: URL(filePath: "/usr/bin/xcodebuild"),
                arguments: args
            )
            guard result.terminationStatus == 0 else { return nil }
            return result.stdout
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)xcodebuild 启动失败: \(error.localizedDescription, privacy: .public)")
            }
            return nil
        }
    }

    nonisolated static func runProcessCapturingStdout(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL? = nil
    ) async throws -> CapturedProcessDataResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL

        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiXcodeProcess-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let stdoutURL = outputDirectory.appendingPathComponent("stdout.log")
        try Data().write(to: stdoutURL)

        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        process.standardOutput = stdoutHandle
        process.standardError = FileHandle.nullDevice

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { terminatedProcess in
                try? stdoutHandle.close()
                let stdout = (try? Data(contentsOf: stdoutURL)) ?? Data()
                try? FileManager.default.removeItem(at: outputDirectory)
                continuation.resume(returning: CapturedProcessDataResult(
                    terminationStatus: terminatedProcess.terminationStatus,
                    stdout: stdout
                ))
            }

            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                try? stdoutHandle.close()
                try? FileManager.default.removeItem(at: outputDirectory)
                continuation.resume(throwing: error)
            }
        }
    }
}
