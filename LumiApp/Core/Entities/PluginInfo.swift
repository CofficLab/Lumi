import Foundation

/// 插件设置列表中的可配置项描述。
struct PluginInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let isDeveloperEnabled: () -> Bool

    init(
        id: String,
        name: String,
        description: String,
        icon: String = "puzzlepiece.extension",
        isDeveloperEnabled: @escaping () -> Bool = { true }
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.isDeveloperEnabled = isDeveloperEnabled
    }
}
