import AppKit
import Foundation
import MagicKit
import SwiftUI

/// 最近使用项目列表（全局共享，所有窗口共用一份）
///
/// ## 初始化规则
///
/// 由 `RootContainer` 持有并通过 `.environmentObject()` 注入。
/// 所有 View 通过 `@EnvironmentObject var recentProjectsVM: AppRecentProjectsVM` 访问。
/// 非 View 场景（如 Middleware）通过 `SendMessageContext.recentProjectsVM` 传入。
///
/// ## 使用方式
///
/// ```swift
/// // 在 View 中：
/// @EnvironmentObject var recentProjectsVM: AppRecentProjectsVM
/// recentProjectsVM.recentProjects
/// recentProjectsVM.setRecentProjects(projects)
///
/// // 在 Middleware 中：
/// let recentProjects = ctx.recentProjectsVM.getRecentProjects()
/// ```
@MainActor
final class AppRecentProjectsVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose: Bool = false

    /// 最近使用的项目列表（全局唯一）
    @Published public fileprivate(set) var recentProjects: [Project] = []

    func setRecentProjects(_ projects: [Project]) {
        recentProjects = projects
    }

    func getRecentProjects() -> [Project] {
        recentProjects
    }
}
