import AppKit
import Foundation
import MagicKit
import SwiftUI

/// 最近使用项目列表（全局共享，所有窗口共用一份）
@MainActor
final class AppRecentProjectsVM: ObservableObject, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose: Bool = false

    static let shared = AppRecentProjectsVM()

    /// 最近使用的项目列表（全局唯一）
    @Published public fileprivate(set) var recentProjects: [Project] = []

    private init() {}

    func setRecentProjects(_ projects: [Project]) {
        recentProjects = projects
    }

    func getRecentProjects() -> [Project] {
        recentProjects
    }
}
