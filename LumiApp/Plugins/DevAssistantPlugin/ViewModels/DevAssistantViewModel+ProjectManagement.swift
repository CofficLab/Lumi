import Foundation
import OSLog

extension DevAssistantViewModel {
    // MARK: - 项目管理

    /// 切换到指定项目
    func switchProject(to path: String) {
        let projectURL = URL(fileURLWithPath: path)

        // 验证路径是否存在
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            self.errorMessage = "项目路径无效: \(path)"
            return
        }

        let projectName = projectURL.lastPathComponent

        self.currentProjectName = projectName
        self.currentProjectPath = path
        self.isProjectSelected = true

        // 保存到 UserDefaults（记住上次选择的项目）
        UserDefaults.standard.set(path, forKey: "DevAssistant_SelectedProject")

        // 保存到最近使用列表
        saveRecentProject(name: projectName, path: path)

        // 获取或创建项目配置
        let config = ProjectConfigStore.shared.getOrCreateConfig(for: path)

        // 应用项目配置
        applyProjectConfig(config)

        // 更新 ContextService
        Task {
            await ContextService.shared.setProjectRoot(projectURL)

            // 刷新系统提示
            let fullSystemPrompt = await promptService.buildSystemPrompt(
                languagePreference: languagePreference,
                includeContext: true
            )

            // 更新第一条系统消息
            if !messages.isEmpty, messages[0].role == .system {
                messages[0] = ChatMessage(role: .system, content: fullSystemPrompt)
            } else {
                messages.insert(ChatMessage(role: .system, content: fullSystemPrompt), at: 0)
            }

            // 添加切换项目通知（根据语言偏好）
            let switchMessage: String
            switch languagePreference {
            case .chinese:
                switchMessage = """
                ✅ 已切换到项目

                **项目名称**: \(projectName)
                **项目路径**: \(path)
                **使用模型**: \(config.model.isEmpty ? "默认" : config.model) (\(config.providerId))
                """
            case .english:
                switchMessage = """
                ✅ Switched to project

                **Project**: \(projectName)
                **Path**: \(path)
                **Model**: \(config.model.isEmpty ? "Default" : config.model) (\(config.providerId))
                """
            }

            messages.append(ChatMessage(role: .assistant, content: switchMessage))

            if Self.verbose {
                os_log("\(self.t)已切换到项目: \(projectName) (\(path))")
                os_log("\(self.t)项目配置: 供应商=\(config.providerId), 模型=\(config.model)")
            }
        }
    }

    /// 应用项目配置
    func applyProjectConfig(_ config: ProjectConfig) {
        // 切换供应商
        if !config.providerId.isEmpty {
            selectedProviderId = config.providerId
        }

        // 切换模型
        if !config.model.isEmpty {
            updateSelectedModel(config.model)
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
