import Combine
import Foundation
import LumiCoreKit
import os
import SuperLogKit

/// 协调 ViewModel 与 LumiCore 之间的同步。
/// 
/// 职责：
/// - 监听 ViewModel 的 @Published 属性变化，同步到 LumiCore
/// - 监听 LumiCore 的项目变更通知（预留，暂未实现反向同步）
/// 
/// 注意：初始化时会立即执行一次初始同步，确保 LumiCore 的状态与磁盘数据一致。
@MainActor
public final class ProjectsSyncCoordinator: SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects.sync")
    public nonisolated static let emoji = "🔄"
    public static var verbose = true

    private let viewModel: ProjectsViewModel
    private var cancellables = Set<AnyCancellable>()

    /// LumiCore 实例，用于同步项目状态。
    public weak var lumiCore: (any LumiCoreAccessing)? {
        didSet {
            // 当 lumiCore 被设置时，立即执行初始同步
            if lumiCore != nil {
                performInitialSync()
            }
        }
    }

    public init(viewModel: ProjectsViewModel) {
        self.viewModel = viewModel
        observeViewModelChanges()
        observeProjectNotifications()
    }

    // MARK: - Initial Sync

    /// 执行初始同步，将 ViewModel 的当前状态同步到 LumiCore。
    /// 在 lumiCore 被设置时自动调用。
    private func performInitialSync() {
        guard Self.verbose else { return }
        Self.logger.info("\(Self.t)执行初始同步, 项目数量: \(self.viewModel.projects.count), 当前项目: \(self.viewModel.currentProject?.name ?? "nil")")
        
        // 直接调用同步方法
        syncProjectsToLumiCore(self.viewModel.projects)
        syncCurrentProjectToLumiCore(self.viewModel.currentProject)
    }

    // MARK: - ViewModel → LumiCore

    private func observeViewModelChanges() {
        viewModel.$projects
            .dropFirst() // 跳过初始值，初始同步在 performInitialSync 中处理
            .sink { [weak self] projects in
                self?.syncProjectsToLumiCore(projects)
            }
            .store(in: &cancellables)

        viewModel.$currentProject
            .dropFirst() // 跳过初始值
            .sink { [weak self] project in
                self?.syncCurrentProjectToLumiCore(project)
            }
            .store(in: &cancellables)
    }

    private func syncProjectsToLumiCore(_ projects: [LumiProjectEntry]) {
        guard let projectState = lumiCore?.projectState else {
            if Self.verbose {
                Self.logger.debug("\(Self.t)syncProjectsToLumiCore 跳过: lumiCore 未设置")
            }
            return
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)同步 \(projects.count) 个项目到 LumiCore")
        }

        for project in projects {
            projectState.addProject(project)
        }
    }

    private func syncCurrentProjectToLumiCore(_ project: LumiProjectEntry?) {
        guard let projectState = lumiCore?.projectState else {
            if Self.verbose {
                Self.logger.debug("\(Self.t)syncCurrentProjectToLumiCore 跳过: lumiCore 未设置")
            }
            return
        }

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

    // MARK: - LumiCore → ViewModel (预留)

    private func observeProjectNotifications() {
        NotificationCenter.default.publisher(for: .currentProjectDidChange)
            .sink { notification in
                let project = notification.userInfo?["project"] as? LumiProjectEntry
                if Self.verbose {
                    Self.logger.info("\(Self.t)LumiCore 当前项目变更: \(project?.name ?? "nil") @ \(project?.path ?? "")")
                }
                // TODO: 未来可以实现反向同步到 ViewModel
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .projectListDidChange)
            .sink { _ in
                if Self.verbose {
                    Self.logger.info("\(Self.t)LumiCore 项目列表变更")
                }
                // TODO: 未来可以实现反向同步到 ViewModel
            }
            .store(in: &cancellables)
    }
}
