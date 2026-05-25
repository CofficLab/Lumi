import SwiftUI
import LumiCoreKit

actor IdleTimePlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🌙"
    static var category: PluginCategory { .general }
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

    static let id: String = "IdleTime"
    static let navigationId: String? = nil
    static let displayName: String = "Idle Time"
    static let description: String = "Infer rest windows for background scheduling"
    static let iconName: String = "moon.zzz"
    static let isConfigurable: Bool = false
    static var order: Int { 96 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = IdleTimePlugin()

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(IdleTimeRootObserver(content: content()))
    }

    @MainActor
    func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(IdleStatusBarView())
    }

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(IdleTimeSendMiddleware())]
    }
}
