import Foundation
import os
import LumiKernel

/// Project cleaner service - scans development directories for cleanable project dependencies.
public final class ProjectCleanerService: @unchecked Sendable {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "project-cleaner")
    public static let shared = ProjectCleanerService()
    private let fileManager = FileManager.default

    private init() {}

    private let defaultScanPaths = [
        "\(NSHomeDirectory())/Code",
        "\(NSHomeDirectory())/Projects",
        "\(NSHomeDirectory())/Developer",
        "\(NSHomeDirectory())/IdeaProjects",
        "\(NSHomeDirectory())/WebstormProjects",
        "\(NSHomeDirectory())/Documents/GitHub"
    ]

    public func scanProjects() async -> [ProjectInfo] {
        let pathsToScan = defaultScanPaths.filter { fileManager.fileExists(atPath: $0) }
        return await coordinator.scanProjects(pathsToScan)
    }

    public func progressStream() async -> AsyncStream<String> {
        await coordinator.progressStream()
    }

    public func cancelScan() async {
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

        if let project = await detectProject(at: url) {
            projects.append(project)
            return projects
        }

        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        for contentUrl in contents {
            if Task.isCancelled { break }
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: contentUrl.path, isDirectory: &isDir), isDir.boolValue {
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

    public func cleanProjects(_ items: [CleanableItem]) async throws {
        try await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            for item in items {
                try fileManager.removeItem(atPath: item.path)
            }
        }.value
    }

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
        currentProgress = LumiPluginLocalization.string("Starting scan...", bundle: .module)

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
