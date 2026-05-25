import Foundation
import AgentToolKit
import PluginShowImage
import SwiftUI
import os

/// Show Image 插件 App 侧注册适配器。
///
/// 当前 App 仍通过 ObjC runtime 扫描 `Lumi.*Plugin` 类注册插件；
/// package 中的 `PluginShowImage.ShowImagePlugin` 不在 `Lumi` 命名空间内，
/// 因此这里保留一个薄适配器，实际实现转发给 package 插件。
actor ShowImagePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.show-image")

    nonisolated static let emoji = "🖼️"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

    static let id: String = PluginShowImage.ShowImagePlugin.id
    static let displayName: String = PluginShowImage.ShowImagePlugin.displayName
    static let description: String = PluginShowImage.ShowImagePlugin.description
    static let iconName: String = PluginShowImage.ShowImagePlugin.iconName
    static let isConfigurable: Bool = PluginShowImage.ShowImagePlugin.isConfigurable
    static var category: PluginCategory { .integration }
    static var order: Int { PluginShowImage.ShowImagePlugin.order }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = ShowImagePlugin()

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("\(Self.t)📝 已注册")
        }
    }

    nonisolated func onEnable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 已启用")
        }
    }

    nonisolated func onDisable() {
        if Self.verbose {
            Self.logger.info("\(Self.t)⛔️ 已禁用")
        }
    }

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(PluginShowImage.ShowImageOverlay { content() })
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [PluginShowImage.ShowImageTool()]
    }
}
