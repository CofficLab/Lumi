import Combine
import Foundation
import LumiKernel
import os
import SuperLogKit

/// 协调 `ProjectsViewModel` 与 `LumiKernel.project` 之间的同步。
@MainActor
public final class ProjectsSyncCoordinator: SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects.sync")
    public nonisolated static let emoji = "🔄"
    public static var verbose = false

    // MARK: - 属性

    private let viewModel: ProjectsViewModel
    private var cancellables = Set<AnyCancellable>()
    private var isSyncingFromCoordinator = false

    /// LumiKernel 实例，用于同步项目状态。
    public weak var kernel: LumiKernel? {
        didSet {
            guard kernel != nil, oldValue == nil else { return }
            observeKernelChanges()
            performInitialSync()
        }
    }

    // MARK: - 初始化

    public init(viewModel: ProjectsViewModel) {
        self.viewModel = viewModel
        observeViewModelChanges()
    }

    // MARK: - 初始同步

    private func performInitialSync() {
        if Self.verbose {
            Self.logger.info("\(Self.t)执行初始同步, 项目数量: \(self.viewModel.projects.count)")
        }
        // 在 @MainActor 上下文中调用
        Task { @MainActor in
            await self.syncToKernel()
        }
    }

    // MARK: - ViewModel → Kernel

    private func observeViewModelChanges() {
        viewModel.$projects
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                // 在 @MainActor 上下文中调用
                Task { @MainActor in
                    await self.syncToKernel()
                }
            }
            .store(in: &cancellables)

        viewModel.$currentProject
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                // 在 @MainActor 上下文中调用
                Task { @MainActor in
                    await self.syncToKernel()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Kernel → ViewModel

    /// 外部入口（例如将目录拖到 Lumi Dock 图标）会直接更新 Kernel 项目。
    /// 监听 Kernel 的 objectWillChange，并在本轮属性更新完成后读取最新项目，
    /// 通过 ViewModel 的 intent 统一完成添加、选中和磁盘持久化。
    private func observeKernelChanges() {
        guard let project = kernel?.project else { return }

        project.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    // ObservableObjectPublisher 在 @Published 属性写入前发出。
                    await Task.yield()
                    self?.syncFromKernel()
                }
            }
            .store(in: &cancellables)
    }

    private func syncFromKernel() {
        guard !isSyncingFromCoordinator,
              let projectPath = kernel?.project?.currentProject?.path,
              !projectPath.isEmpty
        else { return }

        let currentViewModelPath = viewModel.currentProject?.path
        guard currentViewModelPath != projectPath else { return }

        if Self.verbose {
            Self.logger.info("\(Self.t)同步 Kernel 当前项目到 Projects: \(projectPath)")
        }
        viewModel.setCurrentProjectPath(projectPath)
    }

    private func syncToKernel() async {
        guard let project = kernel?.project else { return }

        isSyncingFromCoordinator = true
        defer { isSyncingFromCoordinator = false }

        let projects = viewModel.projects.map {
            ProjectInfo(name: $0.name, path: $0.path, language: $0.language)
        }
        project.synchronizeProjects(projects)

        // 同步当前项目路径到 kernel
        if let current = viewModel.currentProject {
            try? await project.openProject(at: current.path)
        }
    }
}
