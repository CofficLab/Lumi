import Foundation

extension RootView {
    @MainActor
    func onPreferencesLoaded() {
        if let data = PluginStateStore.shared.data(forKey: "Agent_LanguagePreference"),
           let preference = try? JSONDecoder().decode(LanguagePreference.self, from: data) {
            container.ProjectVM.setLanguagePreference(preference)
        }

        if let modeRaw = PluginStateStore.shared.string(forKey: "Agent_ChatMode"),
           let mode = ChatMode(rawValue: modeRaw) {
            container.ProjectVM.setChatMode(mode)
        }

        if let savedPath = PluginStateStore.shared.string(forKey: "Agent_SelectedProject") {
            container.ProjectVM.switchProject(to: savedPath)
            Task {
                await container.slashCommandService.setCurrentProjectPath(savedPath)
            }
        }
    }
}
