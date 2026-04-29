import Foundation
import MagicKit
import SwiftUI
import os

/// 图片显示插件
///
/// 提供一个 `show_image` 工具，允许 LLM 在 UI 中展示图片。
/// 支持本地文件路径和远程 URL 两种图片源。
///
/// ## 架构
///
/// - `ShowImageState`（@MainActor 单例）：存储从 Environment 同步来的消息队列 VM 引用
/// - `ShowImagePlugin`（Actor）：插件主体，提供 `addRootView` 和工具
/// - `ShowImageOverlay`（View）：通过 `addRootView` 挂载，监听图片显示状态变化
/// - `ShowImageTool`：接收图片路径/URL，触发图片显示
///
/// ## 数据流
///
/// ```
/// EnvironmentObject (messageQueueVM)
///         ↓  (ShowImageOverlay 同步)
/// ShowImageState (@MainActor 单例)
///         ↓  (工具触发)
/// ShowImageTool → ShowImageState → ShowImageOverlay → 图片显示
/// ```
actor ShowImagePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.show-image")

    nonisolated static let emoji = "🖼️"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "ShowImage"
    static let displayName: String = String(localized: "Show Image", table: "ShowImage")
    static let description: String = String(localized: "Display images in the UI with support for local paths and remote URLs.", table: "ShowImage")
    static let iconName: String = "photo.on.rectangle"
    static let isConfigurable: Bool = false
    static var order: Int { 97 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = ShowImagePlugin()

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("\(self.t)📝 已注册")
        }
    }

    nonisolated func onEnable() {
        if Self.verbose {
            Self.logger.info("\(self.t)✅ 已启用")
        }
    }

    nonisolated func onDisable() {
        if Self.verbose {
            Self.logger.info("\(self.t)⛔️ 已禁用")
        }
    }

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ShowImageOverlay(content: content()))
    }

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] {
        [AnyAgentToolFactory(ShowImageToolFactory())]
    }
}

// MARK: - Tool Factory

@MainActor
private struct ShowImageToolFactory: AgentToolFactory {
    let id: String = "show.image.factory"
    let order: Int = 0

    func makeTools(env: AgentToolEnvironment) -> [AgentTool] {
        [ShowImageTool()]
    }
}
