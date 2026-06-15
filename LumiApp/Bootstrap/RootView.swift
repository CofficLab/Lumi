import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

struct RootView<Content: View>: View {
    @ObservedObject private var container: RootContainer
    private let content: Content

    init(container: RootContainer, @ViewBuilder content: () -> Content) {
        self.container = container
        self.content = content()
    }

    var body: some View {
        let context = LumiPluginContext(
            activeSectionID: "app.root",
            activeSectionTitle: "Lumi",
            dependencies: LumiPluginDependencies { dependencies in
                dependencies.register(LumiChatServicing.self, container.chatCoreService.chatService)
                dependencies.register(LumiCurrentProjectPathStoring.self, container.projectPathStore)
                dependencies.register(LumiEditorServicing.self, container.editorCoreService)
            }
        )
        let _ = container.pluginService.registerPluginContributions(context: context)
        let overlays = container.pluginService.rootOverlays(context: context)
        overlays.reduce(AnyView(content)) { wrapped, overlay in
            overlay.apply(to: wrapped)
        }
        .appThemedAppearance()
        .background {
            ThemeWindowAppearanceBridge()
        }
    }
}
