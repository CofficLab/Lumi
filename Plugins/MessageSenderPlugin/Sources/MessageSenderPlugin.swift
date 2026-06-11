import SwiftUI
import LumiCoreKit
import SuperLogKit
import os

/// LLM 消息发送插件：监听 DB 事件，发送 LLM，将结果写回数据库。
public actor MessageSenderPlugin: SuperPlugin, SuperLog {
    nonisolated public static let emoji = "📬"
    public static var category: PluginCategory { .agent }
    nonisolated public static let verbose: Bool = false
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-sender")

    nonisolated public static let policy: PluginPolicy = .alwaysOn

    public static let id: String = "MessageSender"
    public static let displayName: String = LumiPluginLocalization.string("Message Sender", bundle: .module)
    public static let description: String = LumiPluginLocalization.string("Listen for DB events, send LLM requests, and persist responses", bundle: .module)
    public static let iconName: String = "antenna.radiowaves.left.and.right"
    public static var order: Int { 200 }

    nonisolated public var instanceLabel: String { Self.id }
    public static let shared = MessageSenderPlugin()

    private init() {}

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        Self.senderService.configure(plugin: self, runtime: context)
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(DatabaseEventObserver(senderService: Self.senderService, content: content()))
    }
}

extension MessageSenderPlugin {
    @MainActor static let senderService = SenderService()
}
