import Combine
import Foundation
import LumiCoreKit
import os
import SuperLogKit

/// Coordinates synchronization between ProjectsViewModel and LumiCore.
///
/// - ViewModel → LumiCore: Observes ViewModel's `@Published` properties and syncs changes to LumiCore.
/// - LumiCore → ViewModel: Listens to LumiCore notifications for future reverse sync.
///
/// This allows the Store to remain unaware of LumiCore, focusing only on persistence.
@MainActor
public final class ProjectsSyncCoordinator: SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects.sync")
    public nonisolated static let emoji = "🔄"
    public static var verbose = true

    private let viewModel: ProjectsViewModel
    private var cancellables = Set<AnyCancellable>()

    /// LumiCore instance for syncing project state.
    public weak var lumiCore: (any LumiCoreAccessing)?

    public init(viewModel: ProjectsViewModel) {
        self.viewModel = viewModel
        observeViewModelChanges()
        observeProjectNotifications()
    }

    // MARK: - ViewModel → LumiCore

    private func observeViewModelChanges() {
        viewModel.$projects
            .dropFirst()
            .sink { [weak self] projects in
                self?.syncProjectsToLumiCore(projects)
            }
            .store(in: &cancellables)

        viewModel.$currentProject
            .dropFirst()
            .sink { [weak self] project in
                self?.syncCurrentProjectToLumiCore(project)
            }
            .store(in: &cancellables)
    }

    private func syncProjectsToLumiCore(_ projects: [LumiProjectEntry]) {
        guard let projectState = lumiCore?.projectState else { return }
        if Self.verbose {
            Self.logger.info("\(Self.t)同步 \(projects.count) 个项目到 LumiCore")
        }
        for project in projects {
            projectState.addProject(project)
        }
    }

    private func syncCurrentProjectToLumiCore(_ project: LumiProjectEntry?) {
        guard let projectState = lumiCore?.projectState else { return }
        if let project {
            if Self.verbose {
                Self.logger.info("\(Self.t)同步当前项目到 LumiCore: \(project.name) @ \(project.path)")
            }
            projectState.switchToProject(project)
        } else {
            if Self.verbose {
                Self.logger.info("\(Self.t)同步当前项目到 LumiCore: nil (清空)")
            }
            projectState.clearCurrentProject()
        }
    }

    // MARK: - LumiCore → ViewModel

    private func observeProjectNotifications() {
        NotificationCenter.default.publisher(for: .currentProjectDidChange)
            .sink { notification in
                let project = notification.userInfo?["project"] as? LumiProjectEntry
                if Self.verbose {
                    Self.logger.info("\(Self.t)LumiCore 当前项目变更: \(project?.name ?? "nil") @ \(project?.path ?? "")")
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .projectListDidChange)
            .sink { _ in
                if Self.verbose {
                    Self.logger.info("\(Self.t)LumiCore 项目列表变更")
                }
            }
            .store(in: &cancellables)
    }
}
