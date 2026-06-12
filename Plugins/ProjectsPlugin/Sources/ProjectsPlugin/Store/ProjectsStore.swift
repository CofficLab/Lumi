import Foundation
import LumiCoreKit

@MainActor
final class ProjectsStore: ObservableObject {
    @Published private(set) var projects: [LumiProject]
    @Published private(set) var currentProject: LumiProject?

    private static let settingsDirectoryName = "settings"
    private static let projectsFileName = "projects.json"
    private static let currentProjectFileName = "current-project.json"
    private static let maxProjectsCount = 500

    private let settingsDirectory: URL

    init(pluginDirectory: URL = LumiCore.pluginDataDirectory(for: "Projects")) {
        self.settingsDirectory = pluginDirectory
            .appendingPathComponent(Self.settingsDirectoryName, isDirectory: true)
        self.projects = Self.loadProjects(from: settingsDirectory)

        let currentPath = Self.loadCurrentProjectPath(from: settingsDirectory)
        self.currentProject = projects.first { $0.path == currentPath } ?? projects.first
    }

    func select(_ project: LumiProject) {
        let updatedProject = LumiProject(name: project.name, path: project.path)
        projects.removeAll { $0.path == updatedProject.path }
        projects.insert(updatedProject, at: 0)
        projects = Array(projects.prefix(Self.maxProjectsCount))
        currentProject = updatedProject
        save()
    }

    @discardableResult
    func addProject(path: String, select shouldSelect: Bool = false) throws -> LumiProject {
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
            .resolvingSymlinksInPath()
            .standardizedFileURL

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw ProjectsStoreError.pathDoesNotExist(url.path)
        }

        guard isDirectory.boolValue else {
            throw ProjectsStoreError.pathIsNotDirectory(url.path)
        }

        let project = LumiProject(name: url.lastPathComponent, path: url.path)
        if shouldSelect {
            select(project)
        } else {
            add(project)
        }

        return project
    }

    func addProject(url: URL) {
        _ = try? addProject(path: url.path, select: true)
    }

    func remove(_ project: LumiProject) {
        projects.removeAll { $0.path == project.path }

        if currentProject?.path == project.path {
            currentProject = projects.first
        }

        save()
    }

    private func add(_ project: LumiProject) {
        projects.removeAll { $0.path == project.path }
        projects.insert(project, at: 0)
        projects = Array(projects.prefix(Self.maxProjectsCount))

        if currentProject == nil {
            currentProject = projects.first
        }

        save()
    }

    private func save() {
        try? FileManager.default.createDirectory(
            at: settingsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        Self.write(projects, to: projectsFileURL)
        Self.write(currentProject?.path, to: currentProjectFileURL)
    }

    private var projectsFileURL: URL {
        settingsDirectory.appendingPathComponent(Self.projectsFileName, isDirectory: false)
    }

    private var currentProjectFileURL: URL {
        settingsDirectory.appendingPathComponent(Self.currentProjectFileName, isDirectory: false)
    }

    private static func loadProjects(from settingsDirectory: URL) -> [LumiProject] {
        let fileURL = settingsDirectory.appendingPathComponent(projectsFileName, isDirectory: false)

        guard let data = try? Data(contentsOf: fileURL),
              let projects = try? JSONDecoder().decode([LumiProject].self, from: data)
        else {
            return []
        }

        return projects
    }

    private static func loadCurrentProjectPath(from settingsDirectory: URL) -> String? {
        let fileURL = settingsDirectory.appendingPathComponent(currentProjectFileName, isDirectory: false)
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return try? JSONDecoder().decode(String.self, from: data)
    }

    private static func write<Value: Encodable>(_ value: Value, to fileURL: URL) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }

        let temporaryURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(fileURL.lastPathComponent).tmp", isDirectory: false)

        do {
            try data.write(to: temporaryURL, options: .atomic)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
        }
    }
}

enum ProjectsStoreError: LocalizedError {
    case pathDoesNotExist(String)
    case pathIsNotDirectory(String)

    var errorDescription: String? {
        switch self {
        case .pathDoesNotExist(let path):
            "Path does not exist: \(path)"
        case .pathIsNotDirectory(let path):
            "Path is not a directory: \(path)"
        }
    }
}
