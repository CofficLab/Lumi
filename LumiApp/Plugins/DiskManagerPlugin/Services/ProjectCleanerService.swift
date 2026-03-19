import Foundation
import MagicKit

/// 项目清理服务 - 在后台执行扫描和清理操作
class ProjectCleanerService: @unchecked Sendable, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose = true
    static let shared = ProjectCleanerService()
    private let fileManager = FileManager.default

    // 注意：状态管理已移至 ViewModel，Service 只负责后台操作
    private init() {}

    // Common development directories
    private let defaultScanPaths = [
        "\(NSHomeDirectory())/Code",
        "\(NSHomeDirectory())/Projects",
        "\(NSHomeDirectory())/Developer",
        "\(NSHomeDirectory())/IdeaProjects",
        "\(NSHomeDirectory())/WebstormProjects",
        "\(NSHomeDirectory())/Documents/GitHub"
    ]

    func scanProjects() async -> [ProjectInfo] {
        if Self.verbose {
            DiskManagerPlugin.logger.info("\(self.t)开始扫描项目目录")
        }
        let pathsToScan = defaultScanPaths.filter { fileManager.fileExists(atPath: $0) }

        let result = await coordinator.scanProjects(pathsToScan)

        if Self.verbose {
            DiskManagerPlugin.logger.info("\(self.t)项目扫描完成：\(result.count) 个项目")
        }
        return result
    }

    func progressStream() async -> AsyncStream<String> {
        await coordinator.progressStream()
    }

    func cancelScan() async {
        await coordinator.cancelCurrentScan()
    }

    nonisolated private static func scanProjectsDetached(_ pathsToScan: [String]) async -> [ProjectInfo] {
        var projects: [ProjectInfo] = []

        await withTaskGroup(of: [ProjectInfo].self) { group in
            for path in pathsToScan {
                group.addTask {
                    await Self.scanDirectory(path, depth: 0, maxDepth: 4)
                }
            }

            for await result in group {
                projects.append(contentsOf: result)
            }
        }

        return projects.sorted { $0.totalSize > $1.totalSize }
    }

    nonisolated fileprivate static func scanDirectory(_ path: String, depth: Int, maxDepth: Int) async -> [ProjectInfo] {
        if Task.isCancelled { return [] }
        if depth > maxDepth { return [] }
        let fileManager = FileManager.default

        var projects: [ProjectInfo] = []
        let url = URL(fileURLWithPath: path)

        // 1. Check if the current directory is a project
        if let project = await detectProject(at: url) {
            projects.append(project)
            // If it's a project, usually we don't scan its subdirectories further (unless it's a Monorepo, here simplified: stop at project)
            // If Monorepo support is needed, scanning can continue
            return projects
        }

        // 2. If it's not a project, continue recursively
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        for contentUrl in contents {
            if Task.isCancelled { break }
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: contentUrl.path, isDirectory: &isDir), isDir.boolValue {
                // Parallel recursion might lead to too many tasks, here using serial recursion to control concurrency
                let subProjects = await Self.scanDirectory(contentUrl.path, depth: depth + 1, maxDepth: maxDepth)
                projects.append(contentsOf: subProjects)
            }
        }

        return projects
    }

    nonisolated private static func detectProject(at url: URL) async -> ProjectInfo? {
        let fileManager = FileManager.default
        let path = url.path
        var type: ProjectInfo.ProjectType?
        var cleanableItems: [CleanableItem] = []

        // Node.js
        if fileManager.fileExists(atPath: url.appendingPathComponent("package.json").path) {
            type = .node
            let nodeModules = url.appendingPathComponent("node_modules")
            if fileManager.fileExists(atPath: nodeModules.path) {
                let size = await DiskService.shared.calculateSize(for: nodeModules)
                if size > 0 {
                    cleanableItems.append(CleanableItem(path: nodeModules.path, name: "node_modules", size: size))
                }
            }
        }
        
        // Rust
        else if fileManager.fileExists(atPath: url.appendingPathComponent("Cargo.toml").path) {
            type = .rust
            let target = url.appendingPathComponent("target")
            if fileManager.fileExists(atPath: target.path) {
                let size = await DiskService.shared.calculateSize(for: target)
                if size > 0 {
                    cleanableItems.append(CleanableItem(path: target.path, name: "target", size: size))
                }
            }
        }
        
        // Swift
        else if fileManager.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            type = .swift
            let build = url.appendingPathComponent(".build")
            if fileManager.fileExists(atPath: build.path) {
                let size = await DiskService.shared.calculateSize(for: build)
                if size > 0 {
                    cleanableItems.append(CleanableItem(path: build.path, name: ".build", size: size))
                }
            }
        }
        
        // Python
        else if fileManager.fileExists(atPath: url.appendingPathComponent("requirements.txt").path) ||
                fileManager.fileExists(atPath: url.appendingPathComponent("pyproject.toml").path) {
            type = .python

            let venv = url.appendingPathComponent("venv")
            if fileManager.fileExists(atPath: venv.path) {
                let size = await DiskService.shared.calculateSize(for: venv)
                cleanableItems.append(CleanableItem(path: venv.path, name: "venv", size: size))
            }

            let dotVenv = url.appendingPathComponent(".venv")
            if fileManager.fileExists(atPath: dotVenv.path) {
                let size = await DiskService.shared.calculateSize(for: dotVenv)
                cleanableItems.append(CleanableItem(path: dotVenv.path, name: ".venv", size: size))
            }

            // __pycache__ is scattered, deep pycache not handled for now
        }

        if let projectType = type, !cleanableItems.isEmpty {
            return ProjectInfo(
                name: url.lastPathComponent,
                path: path,
                type: projectType,
                cleanableItems: cleanableItems
            )
        }
        
        return nil
    }

    func cleanProjects(_ items: [CleanableItem]) async throws {
        if Self.verbose {
            DiskManagerPlugin.logger.info("\(self.t)开始清理 \(items.count) 个项目依赖")
        }
        try await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            for item in items {
                try fileManager.removeItem(atPath: item.path)
            }
        }.value
        if Self.verbose {
            DiskManagerPlugin.logger.info("\(self.t)项目清理完成")
        }
    }

    // MARK: - Coordinator
    private let coordinator = ProjectScanCoordinator()
}

actor ProjectScanCoordinator {
    private var activeTask: Task<[ProjectInfo], Never>?
    private var scanID: UUID = UUID()
    private var currentProgress: String? {
        didSet {
            if let p = currentProgress {
                for (_, cont) in continuations { cont.yield(p) }
            }
        }
    }
    private var continuations: [UUID: AsyncStream<String>.Continuation] = [:]

    func progressStream() -> AsyncStream<String> {
        let id = UUID()
        return AsyncStream { continuation in
            Task { await self.addContinuation(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(id: id) }
            }
        }
    }

    private func addContinuation(id: UUID, continuation: AsyncStream<String>.Continuation) {
        continuations[id] = continuation
        if let p = currentProgress { continuation.yield(p) }
    }

    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }

    func scanProjects(_ paths: [String]) async -> [ProjectInfo] {
        activeTask?.cancel()
        let myID = UUID()
        scanID = myID
        currentProgress = String(localized: "Starting scan...")

        let task = Task { await performScan(paths: paths, id: myID) }
        activeTask = task
        let result = await task.value

        currentProgress = nil
        finishAll()
        return result
    }

    func cancelCurrentScan() {
        activeTask?.cancel()
        activeTask = nil
        currentProgress = nil
        scanID = UUID()
        finishAll()
    }

    private func performScan(paths: [String], id: UUID) async -> [ProjectInfo] {
        var projects: [ProjectInfo] = []
        for path in paths {
            if Task.isCancelled { break }
            if scanID != id { break }
            currentProgress = URL(fileURLWithPath: path).lastPathComponent
            let found = await ProjectCleanerService.scanDirectory(path, depth: 0, maxDepth: 4)
            projects.append(contentsOf: found)
        }
        return projects.sorted { $0.totalSize > $1.totalSize }
    }

    private func finishAll() {
        for (_, cont) in continuations { cont.finish() }
        continuations.removeAll()
    }
}
