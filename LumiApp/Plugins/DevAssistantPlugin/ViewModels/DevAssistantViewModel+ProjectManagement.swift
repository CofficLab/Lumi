import Foundation
import OSLog

extension DevAssistantViewModel {
    // MARK: - 项目管理

    /// 切换到指定项目
    func switchProject(to path: String) {
        let projectURL = URL(fileURLWithPath: path)
        let projectName = projectURL.lastPathComponent

        self.currentProjectName = projectName
        self.currentProjectPath = path

        // 保存到最近使用列表
        saveRecentProject(name: projectName, path: path)

        // 更新 ContextService
        Task {
            await ContextService.shared.setProjectRoot(projectURL)

            // 刷新系统提示
            let context = await ContextService.shared.getContextPrompt()
            let fullSystemPrompt = systemPrompt + "\n\n" + context

            // 更新第一条系统消息
            if !messages.isEmpty, messages[0].role == .system {
                messages[0] = ChatMessage(role: .system, content: fullSystemPrompt)
            } else {
                messages.insert(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
            }

            // 添加切换项目通知
            messages.append(ChatMessage(
                role: .assistant,
                content: "已切换到项目：**\(projectName)**\n\n路径：`\(path)`"
            ))

            if Self.verbose {
                os_log("\(self.t)已切换到项目: \(projectName) (\(path))")
            }
        }
    }

    /// 保存最近使用的项目
    private func saveRecentProject(name: String, path: String) {
        var projects = getRecentProjects()

        // 移除已存在的同名项目
        projects.removeAll { $0.path == path }

        // 添加新项目到开头
        let newProject = RecentProject(name: name, path: path, lastUsed: Date())
        projects.insert(newProject, at: 0)

        // 只保留最近 5 个
        projects = Array(projects.prefix(5))

        // 保存到 UserDefaults
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: "RecentProjects")
        }
    }

    /// 获取最近使用的项目列表
    func getRecentProjects() -> [RecentProject] {
        guard let data = UserDefaults.standard.data(forKey: "RecentProjects"),
              let projects = try? JSONDecoder().decode([RecentProject].self, from: data) else {
            return []
        }
        return projects
    }
}