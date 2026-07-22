import Combine
import Foundation
import SuperLogKit
import os

/// 项目状态管理器
@MainActor
public final class ProjectState: ObservableObject, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "core.project-state")
    public nonisolated static let emoji = "📂"
    public static var verbose = false

    @Published public private(set) var currentProject: ProjectEntry? {
        didSet {
            if currentProject != oldValue {
                if Self.verbose {
                    Self.logger.info("\(Self.t)currentProject didSet: \(oldValue?.name ?? "nil") → \(self.currentProject?.name ?? "nil") @ \(self.currentProject?.path ?? "")")
                }
                if let project = currentProject {
                    NotificationCenter.postCurrentProjectDidChange(project: project)
                    if Self.verbose {
                        Self.logger.info("\(Self.t)发送 CurrentProjectDidChange 通知")
                    }
                }
            }
        }
    }

    @Published public private(set) var projects: [ProjectEntry] = [] {
        didSet {
            if projects != oldValue {
                NotificationCenter.postProjectListDidChange()
            }
        }
    }

    public init() {}

    public func setCurrentProjectPath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            currentProject = nil
            return
        }

        let normalized = Self.normalizePath(trimmed)

        if let existing = projects.first(where: { $0.path == normalized }) {
            currentProject = existing
            return
        }

        let entry = ProjectEntry(
            name: Self.directoryName(for: normalized),
            path: normalized,
            language: ProjectLanguageDetector.detect(at: normalized)
        )
        switchToProject(entry)
    }

    public func switchToProject(_ entry: ProjectEntry) {
        if Self.verbose {
            Self.logger.info("\(Self.t)switchToProject: \(entry.name) @ \(entry.path)")
        }
        currentProject = entry

        if !projects.contains(where: { $0.path == entry.path }) {
            var updatedProjects = projects
            updatedProjects.insert(entry, at: 0)
            projects = updatedProjects
            if Self.verbose {
                Self.logger.info("\(Self.t)项目不在列表中，添加到列表顶部")
            }
        }
    }

    public func clearCurrentProject() {
        currentProject = nil
    }

    public func addProject(_ entry: ProjectEntry) {
        if let index = projects.firstIndex(where: { $0.path == entry.path }) {
            var updatedProjects = projects
            updatedProjects[index] = entry
            projects = updatedProjects
        } else {
            var updatedProjects = projects
            updatedProjects.insert(entry, at: 0)
            projects = updatedProjects
        }
    }

    public func removeProject(_ entry: ProjectEntry) {
        var updatedProjects = projects
        updatedProjects.removeAll { $0.path == entry.path }
        projects = updatedProjects

        if currentProject?.path == entry.path {
            currentProject = nil
        }
    }

    private static func normalizePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        return url.path
    }

    private static func directoryName(for path: String) -> String {
        let name = URL(fileURLWithPath: path).lastPathComponent
        return name.isEmpty ? path : name
    }
}
