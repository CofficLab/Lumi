import Foundation
import MagicKit

/// 处理偏好设置加载
enum PreferencesLoadHandler {
    /// 加载用户偏好设置
    /// - Parameters:
    ///   - projectVM: 项目视图模型
    ///   - slashCommandService: 斜杠命令服务
    @MainActor
    static func handle(projectVM: ProjectVM, slashCommandService: SlashCommandService) {
        // 加载语言偏好
        if let data = PluginStateStore.shared.data(forKey: "Agent_LanguagePreference"),
           let preference = try? JSONDecoder().decode(LanguagePreference.self, from: data) {
            projectVM.setLanguagePreference(preference)
        }

        // 加载聊天模式
        if let modeRaw = PluginStateStore.shared.string(forKey: "Agent_ChatMode"),
           let mode = ChatMode(rawValue: modeRaw) {
            projectVM.setChatMode(mode)
        }

        // 加载选中的项目路径
        if let savedPath = PluginStateStore.shared.string(forKey: "Agent_SelectedProject") {
            projectVM.switchProject(to: savedPath)
            Task {
                await slashCommandService.setCurrentProjectPath(savedPath)
            }
        }
    }
}
