import Combine
import Foundation
import LumiCoreKit
import os
import SuperLogKit

/// 协调 `ProjectsViewModel` 与 `LumiCore.projectState` 之间的同步。
///
/// ## 同步方向
/// 数据流：`ViewModel → LumiCore`。Coordinator 把 ViewModel 的状态单向推送给 LumiCore，
/// 不做反向同步。修改此方向时必须保证不会形成 A→B→A→B 的同步循环。
///
/// ## 不变量
/// - **初始同步仅一次**：`lumiCore` 在 `nil → 非 nil` 时执行一次初始同步，后续赋值不再触发。
/// - **写入路径带同步源标记**：所有对 `projectState` 的写入都必须在 `isSyncingFromCoordinator = true`
///   区间内完成，便于未来启用反向同步时跳过自己产生的通知。
/// - **写入幂等**：内容（按 `path` 集合）相同或 ViewModel 项目列表为空时跳过写入，
///   避免重复触发 `projectState.projects` / `currentProject` 的 `didSet`。
@MainActor
public final class ProjectsSyncCoordinator: SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects.sync")
    public nonisolated static let emoji = "🔄"
    public static var verbose = false

    // MARK: - 属性

    private let viewModel: ProjectsViewModel
    private var cancellables = Set<AnyCancellable>()

    /// 同步源标记：当 Coordinator 正在把 ViewModel 的变更推送给 LumiCore 时为 `true`。
    ///
    /// 未来若启用反向同步（`LumiCore → ViewModel`），通知回调必须先检查此标记并跳过，
    /// 否则会形成 A→B→A→B 的同步死循环。
    private var isSyncingFromCoordinator = false

    /// LumiCore 实例，用于同步项目状态。
    ///
    /// 只在 **nil → 非 nil** 的首次绑定时执行初始同步，避免因外部多次赋值
    /// （例如插件生命周期、reload、热替换）重复触发同步流程。
    public weak var lumiCore: (any LumiCoreAccessing)? {
        didSet {
            // 仅在首次绑定时执行初始同步
            guard lumiCore != nil, oldValue == nil else { return }
            performInitialSync()
        }
    }

    // MARK: - 初始化

    public init(viewModel: ProjectsViewModel) {
        self.viewModel = viewModel
        observeViewModelChanges()
        observeProjectNotifications()
    }

    // MARK: - 初始同步

    /// 把 ViewModel 当前的状态推送给 LumiCore。
    ///
    /// 仅在 `lumiCore` 从 nil 变为非 nil 时由 `didSet` 调用一次。
    /// 项目列表为空时**不写入**，避免用空数组覆盖 LumiCore 已有的项目状态
    /// （例如其他插件/模块已经注册过的项目）。
    /// 当前项目为 nil 时仍会写入（合法状态：未选中任何项目）。
    private func performInitialSync() {
        if Self.verbose {
            Self.logger.info("\(Self.t)执行初始同步, 项目数量: \(self.viewModel.projects.count), 当前项目: \(self.viewModel.currentProject?.name ?? "nil")")
        }

        syncProjectsToLumiCore(self.viewModel.projects)
        syncCurrentProjectToLumiCore(self.viewModel.currentProject)
    }

    // MARK: - ViewModel → LumiCore

    /// 监听 ViewModel 的 `@Published` 变化并推送给 LumiCore。
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

    /// 把项目列表同步给 LumiCore。内容（按 path 集合）相同时跳过，避免重复写入触发 `didSet`。
    ///
    /// 用 `path` 集合而不是 `LumiProjectEntry` 的 `==` 是因为：
    /// - `LumiProjectEntry` 的 `lastUsed` 字段在 ViewModel 重建 entry 时会被刷新，
    ///   导致逐字段 `==` 几乎永远不成立。
    /// - 业务上两个项目集合是否"等价"取决于路径身份，而非时间戳。
    private func syncProjectsToLumiCore(_ projects: [LumiProjectEntry]) {
        guard let projectState = lumiCore?.projectState else {
            if Self.verbose {
                Self.logger.debug("\(Self.t)syncProjectsToLumiCore 跳过: lumiCore 未设置")
            }
            return
        }

        // 保护：空列表不写入，避免覆盖 LumiCore 已有的项目（可能是其他模块注册的）。
        if projects.isEmpty {
            if Self.verbose {
                Self.logger.debug("\(Self.t)syncProjectsToLumiCore 跳过: ViewModel 项目列表为空")
            }
            return
        }

        // 幂等检查：按 path 集合判断内容是否相同。
        let existingPaths = Set(projectState.projects.map(\.path))
        let incomingPaths = Set(projects.map(\.path))
        if existingPaths == incomingPaths {
            if Self.verbose {
                Self.logger.debug("\(Self.t)syncProjectsToLumiCore 跳过: 内容相同 (\(projects.count) 个项目)")
            }
            return
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)同步 \(projects.count) 个项目到 LumiCore")
        }

        // 标记同步源，防止未来启用反向同步时形成循环
        isSyncingFromCoordinator = true
        defer { isSyncingFromCoordinator = false }

        for project in projects {
            projectState.addProject(project)
        }
    }

    /// 把当前项目同步给 LumiCore。
    private func syncCurrentProjectToLumiCore(_ project: LumiProjectEntry?) {
        guard let projectState = lumiCore?.projectState else {
            if Self.verbose {
                Self.logger.debug("\(Self.t)syncCurrentProjectToLumiCore 跳过: lumiCore 未设置")
            }
            return
        }

        // 幂等检查：按 path 判断。nil 和 nil 视为相等；其他情况比较 path。
        let currentPath = projectState.currentProject?.path
        let incomingPath = project?.path
        if currentPath == incomingPath {
            if Self.verbose {
                Self.logger.debug("\(Self.t)syncCurrentProjectToLumiCore 跳过: 内容相同 (\(project?.name ?? "nil"))")
            }
            return
        }

        // 标记同步源，防止未来启用反向同步时形成循环
        isSyncingFromCoordinator = true
        defer { isSyncingFromCoordinator = false }

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

    /// 监听 LumiCore 的项目变更通知。
    ///
    /// 当前只记录日志，不回写到 ViewModel（单向同步设计）。
    /// 若未来启用反向同步，必须在 sink 中检查 `isSyncingFromCoordinator`，
    /// 跳过由 Coordinator 自己写入产生的通知，避免循环。
    private func observeProjectNotifications() {
        NotificationCenter.default.publisher(for: .currentProjectDidChange)
            .sink { notification in
                let project = notification.userInfo?["project"] as? LumiProjectEntry
                // TODO: 反向同步启用时，需要先解开下一行注释并捕获 self（参考 syncProjectsToLumiCore）。
                // guard !isSyncingFromCoordinator else { return }

                if Self.verbose {
                    Self.logger.info("\(Self.t)LumiCore 当前项目变更: \(project?.name ?? "nil") @ \(project?.path ?? "")")
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .projectListDidChange)
            .sink { _ in
                // TODO: 反向同步启用时，需要先解开下一行注释并捕获 self（参考 syncProjectsToLumiCore）。
                // guard !isSyncingFromCoordinator else { return }

                if Self.verbose {
                    Self.logger.info("\(Self.t)LumiCore 项目列表变更")
                }
            }
            .store(in: &cancellables)
    }
}
