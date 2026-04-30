import Foundation
import MagicKit
import os

/// Xcode 项目解析器：发现并解析 .xcodeproj / .xcworkspace
/// 对应 Roadmap Phase 1 & Phase 2
@MainActor
final class XcodeProjectResolver: SuperLog {
    
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose = true
    
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode.resolver")
    
    // MARK: - 项目发现
    
    /// 在指定目录中查找 .xcworkspace，找到第一个
    static func findWorkspace(in directory: URL) -> URL? {
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
    static func isXcodeProjectRoot(_ directory: URL) -> Bool {
        findWorkspace(in: directory) != nil
    }
    
    // MARK: - 项目解析
    
    /// 解析一个 workspace / project，返回完整的上下文
    /// 此方法会调用 xcodebuild -list -json 获取结构化数据
    func resolve(workspaceURL: URL) async -> XcodeWorkspaceContext? {
        let isProject = workspaceURL.pathExtension == "xcodeproj"
        let isWorkspace = workspaceURL.pathExtension == "xcworkspace"
        guard isProject || isWorkspace else {
            Self.logger.warning("\(Self.t)无效的项目路径: \(workspaceURL.path, privacy: .public)")
            return nil
        }
        
        let name = workspaceURL.deletingPathExtension().lastPathComponent
        let projectPath = isProject ? workspaceURL : nil
        let workspacePath = isWorkspace ? workspaceURL : nil
        
        // 获取 xcodebuild -list -json 输出
        guard let listResult = await fetchBuildList(workspaceURL: workspacePath, projectURL: projectPath) else {
            Self.logger.error("\(Self.t)无法获取构建列表: \(workspaceURL.path, privacy: .public)")
            return nil
        }
        
        let schemes = (listResult.workspace?.schemes ?? []) + (listResult.project?.schemes ?? [])
        let uniqueSchemes = Array(Set(schemes))
        
        // 解析 targets
        let targetNames = listResult.project?.targets ?? []
        let configurations = listResult.project?.configurations ?? []
        let targetSourceFiles = resolveTargetSourceFiles(projectLikeURL: workspaceURL)
        
        let targetContexts = targetNames.map { targetName in
            let targetConfigurations = configurations.map { configName in
                XcodeBuildConfigurationContext(id: "\(targetName)_\(configName)", name: configName)
            }
            return XcodeTargetContext(
                id: targetName,
                name: targetName,
                productType: nil,
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
    
    /// 解析 scheme 列表
    func resolveSchemes(workspaceURL: URL, projectURL: URL?) async -> [XcodeSchemeContext] {
        guard let listResult = await fetchBuildList(workspaceURL: workspaceURL, projectURL: projectURL) else {
            return []
        }
        
        let schemeNames = (listResult.workspace?.schemes ?? []) + (listResult.project?.schemes ?? [])
        let uniqueSchemes = Array(Set(schemeNames))
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
            Self.logger.error("\(Self.t)解析构建列表失败: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    /// 执行 `xcodebuild -showBuildSettings -json`
    func fetchBuildSettings(workspaceURL: URL?, projectURL: URL?, scheme: String, configuration: String? = nil, destination: String? = nil) async -> [[String: String]]? {
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
            Self.logger.error("\(Self.t)解析构建设置失败: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    // MARK: - 工具方法

    private func resolveTargetSourceFiles(projectLikeURL: URL) -> [String: Set<String>] {
        let projectURL: URL
        if projectLikeURL.pathExtension == "xcodeproj" {
            projectURL = projectLikeURL
        } else {
            let directoryURL = projectLikeURL.deletingLastPathComponent()
            let preferredCandidate = directoryURL.appendingPathComponent(projectLikeURL.deletingPathExtension().lastPathComponent + ".xcodeproj")
            if FileManager.default.fileExists(atPath: preferredCandidate.path) {
                projectURL = preferredCandidate
            } else if let fallbackCandidate = try? FileManager.default
                .contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "xcodeproj" }) {
                projectURL = fallbackCandidate
            } else {
                return [:]
            }
        }

        guard let graph = try? XcodePBXProjParser.parseMembershipGraph(projectURL: projectURL) else {
            Self.logger.warning("\(Self.t)无法解析 pbxproj 文件归属: \(projectURL.path, privacy: .public)")
            return [:]
        }

        let projectRoot = projectURL.deletingLastPathComponent()
        return graph.targetRoots.reduce(into: [String: Set<String>]()) { result, item in
            let files = item.value.reduce(into: Set<String>()) { partial, root in
                let rootURL = projectRoot.appendingPathComponent(root.rootPath)
                partial.formUnion(enumerateFiles(in: rootURL, excluding: root.excludedRelativePaths))
            }
            result[item.key] = files
        }
    }

    private func enumerateFiles(in rootURL: URL, excluding excludedRelativePaths: Set<String>) -> Set<String> {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var files = Set<String>()
        while let fileURL = enumerator.nextObject() as? URL {
            let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            if excludedRelativePaths.contains(relativePath) {
                continue
            }
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            if values?.isDirectory == true {
                continue
            }
            if values?.isRegularFile == true {
                files.insert(fileURL.path)
            }
        }
        return files
    }
    
    /// 异步执行 xcodebuild
    private func runXcodeBuild(args: [String]) async -> Data? {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/xcodebuild")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
        } catch {
            Self.logger.error("\(Self.t)xcodebuild 启动失败: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: data)
            }
        }
    }
}
