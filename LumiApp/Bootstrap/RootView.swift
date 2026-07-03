import EditorService
import LumiCoreKit
import LumiUI
import SuperLogKit
import SwiftUI
import os

struct RootView<Content: View>: View {
    @ObservedObject private var container: RootContainer
    private let content: Content
    private let appliesRootOverlays: Bool

    /// - Parameters:
    ///   - container: 全局容器。
    ///   - appliesRootOverlays: 是否应用插件 root overlays（如 Onboarding）。
    ///     主窗口传 `true`，设置等辅助窗口传 `false` 以避免重复弹出。
    init(container: RootContainer, appliesRootOverlays: Bool = true, @ViewBuilder content: () -> Content) {
        self.container = container
        self.appliesRootOverlays = appliesRootOverlays
        self.content = content()
    }

    var body: some View {
        let context = container.lumiCoreService.makePluginContext(
            activeSectionID: "app.root",
            activeSectionTitle: "Lumi",
            chatService: container.chatCoreService.chatService,
            editorService: container.editorCoreService
        )
        let _ = container.pluginService.registerPluginContributions(context: context)
        let onboardingPages = container.pluginService.onboardingPages(context: context)
        let baseView = AnyView(content)
        let overlayView = appliesRootOverlays
            ? container.pluginService.rootOverlays(context: context).reduce(baseView) { wrapped, overlay in
                overlay.apply(to: wrapped)
            }
            : baseView

        return overlayView
            .environment(\.onboardingPages, onboardingPages)
            .appThemedAppearance()
            .background {
                ThemeWindowAppearanceBridge()
            }
    }
}
