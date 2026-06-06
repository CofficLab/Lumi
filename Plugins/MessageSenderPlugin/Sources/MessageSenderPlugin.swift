import SwiftUI
import LumiCoreKit
import SuperLogKit
import os

/// 数据库事件监听插件
///
/// 通过 `addRootView` 挂载一个不可见的观察者视图，
/// 监听所有数据库事件（消息保存、对话创建/更新/删除）并输出日志。
///
/// ## 监听的事件
///
/// | 事件 | Notification | 日志内容 |
/// |------|-------------|---------|
/// | 消息保存 | `.messageSaved` | 角色 + 内容摘要 + 对话 ID |
/// | 对话创建 | `.conversationCreated` | 对话 ID |
/// | 对话更新 | `.conversationUpdated` | 对话 ID |
/// | 对话删除 | `.conversationDeleted` | 对话 ID |
///
/// ## 设计
///
/// 插件本身是一个 actor，符合 `SuperPlugin` 协议。
/// 通过 `addRootView` 将 `DatabaseEventObserver` 挂载到根视图层级，
/// 使用 SwiftUI 的 `.onReceive` 监听 NotificationCenter 事件。
public actor MessageSenderPlugin: SuperPlugin, SuperLog {
    nonisolated public static let emoji = "📬"
    public static var category: PluginCategory { .developer }
    nonisolated public static let verbose: Bool = true
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-sender")

    nonisolated public static let policy: PluginPolicy = .configurable(enabledByDefault: false)

    public static let id: String = "MessageSender"
    public static let displayName: String = "Database Event Logger"
    public static let description: String = "Monitor database events (message save, conversation CRUD) and output logs"
    public static let iconName: String = "antenna.radiowaves.left.and.right"
    public static var order: Int { 200 }

    nonisolated public var instanceLabel: String { Self.id }
    public static let shared = MessageSenderPlugin()

    private init() {}

    // MARK: - Root View

    /// 挂载不可见的事件观察者到根视图层级
    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(DatabaseEventObserver(content: content()))
    }
}

// MARK: - Event Observer

/// 不可见的数据库事件观察者
///
/// 挂载在根视图层级，监听所有数据库相关的 NotificationCenter 事件，
/// 格式化后通过 `SuperLog` 输出。
private struct DatabaseEventObserver<Content: View>: View {
    let content: Content

    @State private var eventCount = 0

    var body: some View {
        content
            // 消息保存
            .onReceive(NotificationCenter.default.publisher(for: .messageSaved)) { notification in
                if let message = notification.object as? ChatMessage,
                   let conversationId = notification.userInfo?["conversationId"] as? UUID {
                    eventCount += 1
                    let preview = String(message.content.prefix(80)).replacingOccurrences(of: "\n", with: "↵")
                    MessageSenderPlugin.logger.info("\(MessageSenderPlugin.t)📨 [\(eventCount)] messageSaved | role=\(message.role.rawValue) | conv=\(conversationId.uuidString.prefix(8))… | \"\(preview)\"")
                }
            }
            // 对话创建
            .onReceive(NotificationCenter.default.publisher(for: .conversationCreated)) { notification in
                if let conversationId = notification.object as? UUID {
                    eventCount += 1
                    MessageSenderPlugin.logger.info("\(MessageSenderPlugin.t)📨 [\(eventCount)] conversationCreated | conv=\(conversationId.uuidString.prefix(8))…")
                }
            }
            // 对话更新
            .onReceive(NotificationCenter.default.publisher(for: .conversationUpdated)) { notification in
                if let conversationId = notification.object as? UUID {
                    eventCount += 1
                    MessageSenderPlugin.logger.info("\(MessageSenderPlugin.t)📨 [\(eventCount)] conversationUpdated | conv=\(conversationId.uuidString.prefix(8))…")
                }
            }
            // 对话删除
            .onReceive(NotificationCenter.default.publisher(for: .conversationDeleted)) { notification in
                if let conversationId = notification.object as? UUID {
                    eventCount += 1
                    MessageSenderPlugin.logger.info("\(MessageSenderPlugin.t)📨 [\(eventCount)] conversationDeleted | conv=\(conversationId.uuidString.prefix(8))…")
                }
            }
    }
}
