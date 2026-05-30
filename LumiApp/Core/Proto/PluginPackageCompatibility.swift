import LumiCoreKit

extension PluginCategory {
    init(package value: LumiCoreKit.PluginCategory) {
        self = PluginCategory(rawValue: value.rawValue) ?? .general
    }
}

extension SidebarToolbarItem {
    init(package item: LumiCoreKit.SidebarToolbarItem) {
        self.init(
            id: item.id,
            title: item.title,
            systemImage: item.systemImage,
            priority: item.priority
        )
    }
}

extension ViewContainerItem {
    init(package item: LumiCoreKit.ViewContainerItem) {
        self.init(
            id: item.id,
            title: item.title,
            icon: item.icon,
            showsProjectToolbar: item.showsProjectToolbar,
            supportsAIChat: item.supportsAIChat,
            makeView: item.makeView
        )
    }
}

extension ToolContext {
    var packageContext: LumiCoreKit.ToolContext {
        LumiCoreKit.ToolContext(
            languagePreference: languagePreference
        )
    }
}
