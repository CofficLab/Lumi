import MagicKit
import SwiftUI

actor IdleTimePlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🌙"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

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
    func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        AnyView(IdleStatusBarView())
    }

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(IdleTimeSendMiddleware())]
    }
}
