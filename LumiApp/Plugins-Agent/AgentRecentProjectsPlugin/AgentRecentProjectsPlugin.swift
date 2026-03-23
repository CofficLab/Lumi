import MagicKit
import SwiftUI

/// 最近项目持久化插件
/// 负责保存和恢复最近使用的项目列表
actor AgentRecentProjectsPlugin: SuperPlugin {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = false

    static let id = "AgentRecentProjects"
    static let displayName = String(localized: "Recent Projects", table: "AgentRecentProjects")
    static let description = String(localized: "Persist recent projects list", table: "AgentRecentProjects")
    static let iconName = "clock.arrow.circlepath"
    static var order: Int { 10 }
    static let enable: Bool = true

    static let shared = AgentRecentProjectsPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(RecentProjectsPersistenceOverlay(content: content()))
    }

    @MainActor
    func addRightHeaderLeadingView() -> AnyView? { nil }

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] { [] }
}

// MARK: - Store

/// 最近项目存储
final class RecentProjectsStore: @unchecked Sendable {
    private let key = "Agent_RecentProjects"
    private let queue = DispatchQueue(label: "RecentProjectsStore.queue", qos: .userInitiated)

    /// 加载最近项目列表
    func loadProjects() -> [RecentProject] {
        queue.sync {
            guard let data = PluginStateStore.shared.data(forKey: key),
                  let projects = try? JSONDecoder().decode([RecentProject].self, from: data) else {
                return []
            }
            return projects
        }
    }

    /// 保存最近项目列表
    func saveProjects(_ projects: [RecentProject]) {
        queue.sync {
            guard let data = try? JSONEncoder().encode(projects) else { return }
            PluginStateStore.shared.set(data, forKey: key)
        }
    }

    /// 添加或更新项目到列表开头
    func addProject(name: String, path: String) {
        queue.sync {
            var projects = loadProjectsInternal()
            projects.removeAll { $0.path == path }

            let newProject = RecentProject(name: name, path: path, lastUsed: Date())
            projects.insert(newProject, at: 0)
            projects = Array(projects.prefix(5))

            saveProjectsInternal(projects)
        }
    }

    /// 删除指定项目
    func removeProject(_ project: RecentProject) {
        queue.sync {
            var projects = loadProjectsInternal()
            projects.removeAll { $0.id == project.id }
            saveProjectsInternal(projects)
        }
    }

    private func loadProjectsInternal() -> [RecentProject] {
        guard let data = PluginStateStore.shared.data(forKey: key),
              let projects = try? JSONDecoder().decode([RecentProject].self, from: data) else {
            return []
        }
        return projects
    }

    private func saveProjectsInternal(_ projects: [RecentProject]) {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        PluginStateStore.shared.set(data, forKey: key)
    }
}