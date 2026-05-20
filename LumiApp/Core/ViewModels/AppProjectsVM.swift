import AppKit
import Foundation
import SwiftUI

/// 项目列表（全局共享，所有窗口共用一份）
///
/// ## 初始化规则
///
/// 由 `RootContainer` 持有并通过 `.environmentObject()` 注入。
/// 所有 View 通过 `@EnvironmentObject var recentProjectsVM: AppProjectsVM` 访问。
/// 非 View 场景（如 Middleware）通过 `SendMessageContext.recentProjectsVM` 传入。
///
/// ## 使用方式
///
/// ```swift
/// // 在 View 中：
/// @EnvironmentObject var recentProjectsVM: AppProjectsVM
/// recentProjectsVM.recentProjects
/// recentProjectsVM.setRecentProjects(projects)
///
/// // 在 Middleware 中：
/// let recentProjects = ctx.recentProjectsVM.getRecentProjects()
/// ```
@MainActor
final class AppProjectsVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose: Bool = false

    /// 最近使用的项目列表（全局唯一）
    @Published public fileprivate(set) var recentProjects: [Project] = []

    // MARK: - Write

    /// 全量替换项目列表
    func setRecentProjects(_ projects: [Project]) {
        recentProjects = projects
    }

    /// 添加项目到列表顶部（去重，若已存在则移至顶部）
    func addProject(_ project: Project) {
        recentProjects.removeAll { $0.path == project.path }
        recentProjects.insert(project, at: 0)
    }

    /// 移除指定项目
    func removeProject(_ project: Project) {
        recentProjects.removeAll { $0.path == project.path }
    }

    // MARK: - Read

    func getRecentProjects() -> [Project] {
        recentProjects
    }
}
