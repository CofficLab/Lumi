import AgentToolKit
import Combine
import Foundation

/// Lightweight project model shared with package-ized plugins.
public struct Project: Codable, Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let name: String
    public let path: String
    public let lastUsed: Date

    public enum CodingKeys: String, CodingKey {
        case name, path, lastUsed
    }

    public init(name: String, path: String, lastUsed: Date = Date()) {
        self.name = name
        self.path = path
        self.lastUsed = lastUsed
    }
}

@MainActor
public final class PluginProjectContext: ObservableObject {
    public static var switchProjectHandler: (@MainActor (Project, String) -> Void)?

    @Published public private(set) var currentProjectName: String
    @Published public private(set) var currentProjectPath: String
    @Published public private(set) var languagePreference: LanguagePreference

    public init(
        currentProjectName: String = "",
        currentProjectPath: String = "",
        languagePreference: LanguagePreference = .current
    ) {
        self.currentProjectName = currentProjectName
        self.currentProjectPath = currentProjectPath
        self.languagePreference = languagePreference
    }

    public var isProjectSelected: Bool {
        !currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var currentProject: Project? {
        guard isProjectSelected else { return nil }
        return Project(name: currentProjectName, path: currentProjectPath)
    }

    public func switchProject(to project: Project, reason: String) {
        Self.switchProjectHandler?(project, reason)
        update(
            currentProjectName: project.name,
            currentProjectPath: project.path,
            languagePreference: languagePreference
        )
    }

    public func update(
        currentProjectName: String,
        currentProjectPath: String,
        languagePreference: LanguagePreference
    ) {
        self.currentProjectName = currentProjectName
        self.currentProjectPath = currentProjectPath
        self.languagePreference = languagePreference
    }
}

public typealias WindowProjectVM = PluginProjectContext

@MainActor
public final class AppProjectsVM: ObservableObject {
    @Published public private(set) var recentProjects: [Project]

    public init(recentProjects: [Project] = []) {
        self.recentProjects = recentProjects
    }

    public func setRecentProjects(_ projects: [Project]) {
        recentProjects = projects
    }

    public func addProject(_ project: Project) {
        recentProjects.removeAll { $0.path == project.path }
        recentProjects.insert(project, at: 0)
    }

    public func removeProject(_ project: Project) {
        recentProjects.removeAll { $0.path == project.path }
    }

    public func getRecentProjects() -> [Project] {
        recentProjects
    }
}
