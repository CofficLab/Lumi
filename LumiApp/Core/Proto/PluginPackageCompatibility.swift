import LumiCoreKit
import EditorService
import SwiftUI

extension PluginCategory {
    init(package value: LumiCoreKit.PluginCategory) {
        self = PluginCategory(rawValue: value.rawValue) ?? .general
    }
}

extension RailTab {
    init(package item: LumiCoreKit.RailTab) {
        self.init(
            id: item.id,
            title: item.title,
            systemImage: item.systemImage,
            priority: item.priority
        )
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

extension BottomPanelTab {
    init(package item: LumiCoreKit.BottomPanelTab) {
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

struct PackageMessageRendererAdapter: SuperMessageRenderer {
    private let renderer: any LumiCoreKit.SuperMessageRenderer

    init(_ renderer: any LumiCoreKit.SuperMessageRenderer) {
        self.renderer = renderer
    }

    static var id: String { "package-message-renderer" }
    static var priority: Int { 0 }

    func canRender(message: ChatMessage) -> Bool {
        renderer.canRender(message: message)
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        renderer.render(message: message, showRawMessage: showRawMessage)
    }
}
