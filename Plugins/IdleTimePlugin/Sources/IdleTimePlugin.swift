import SwiftUI
import SuperLogKit
import LumiCoreKit

public actor IdleTimePlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let emoji = "🌙"
    public static var category: PluginCategory { .general }
    public nonisolated static let verbose: Bool = true

    public static let id: String = "IdleTime"
    public static let navigationId: String? = nil
    public static let displayName: String = "Idle Time"
    public static let description: String = "Infer rest windows for background scheduling"
    public static let iconName: String = "moon.zzz"
    public static var order: Int { 96 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = IdleTimePlugin()

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        context.registerIdleTimeSnapshotProvider { date in
            await IdleTimeService.shared.currentSnapshot(for: date)
        }
    }

    @MainActor
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(IdleTimeRootObserver(content: content()))
    }

    @MainActor
    public func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        return AnyView(IdleStatusBarView())
    }

    @MainActor
    public func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(IdleTimeSendMiddleware())]
    }
}
