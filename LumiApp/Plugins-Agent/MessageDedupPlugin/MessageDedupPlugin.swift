import Foundation
import MagicKit
import SwiftUI

/// 消息去重插件
///
/// 监听 `.messageSaved` 事件，检查同一会话中是否存在内容完全一致的消息批次。
/// 如果发现重复消息，只保留最早的一条，删除其余的。
///
/// 通过 `addRootView` 注入 `MessageDedupOverlay`，
/// 在 overlay 中通过环境变量 `ChatHistoryVM` 获取服务来操作数据。
actor MessageDedupPlugin: SuperPlugin {
    nonisolated static let emoji = "🧹"
    nonisolated static let verbose = false

    static let id = "MessageDedup"
    static let displayName = "消息去重"
    static let description = "检测并合并内容完全一致的重复消息"
    static let iconName = "arrow.triangle.2.circlepath"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 7 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = MessageDedupPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - UI

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(MessageDedupOverlay(content: content()))
    }
}
