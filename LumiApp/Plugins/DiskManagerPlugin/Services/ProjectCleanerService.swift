import Foundation

@MainActor
class ProjectCleanerService {
    static let shared = ProjectCleanerService()
    private let fileManager = FileManager.default
    
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
        var projects: [ProjectInfo] = []
        let pathsToScan = defaultScanPaths.filter { fileManager.fileExists(atPath: $0) }
        
        await withTaskGroup(of: [ProjectInfo].self) { group in
            for path in pathsToScan {
                group.addTask {
                    return await self.scanDirectory(path, depth: 0, maxDepth: 4)
                }
            }
            
            for await result in group {
                projects.append(contentsOf: result)
            }
        }
        
        return projects.sorted { $0.totalSize > $1.totalSize }
    }
    
    private func scanDirectory(_ path: String, depth: Int, maxDepth: Int) async -> [ProjectInfo] {
        if depth > maxDepth { return [] }
        
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
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: contentUrl.path, isDirectory: &isDir), isDir.boolValue {
                // Parallel recursion might lead to too many tasks, here using serial recursion to control concurrency
                let subProjects = await scanDirectory(contentUrl.path, depth: depth + 1, maxDepth: maxDepth)
                projects.append(contentsOf: subProjects)
            }
        }
        
        return projects
    }
    
    private func detectProject(at url: URL) async -> ProjectInfo? {
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
        for item in items {
            try fileManager.removeItem(atPath: item.path)
        }
    }
}
