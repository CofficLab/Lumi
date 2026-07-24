import LumiKernel
import LumiUI
import SwiftUI

/// 新版应用主布局
///
/// 基于 `LumiKernel` 构建，View 层只读 kernel，不知道是哪个插件控制了哪些能力。
struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    var body: some View {
        let containers = kernel.viewContainer?.allViewContainers ?? []
        let activeID = kernel.layout?.activeViewContainerID
            ?? kernel.layout?.state.activeSectionID
            ?? containers.first?.id
            ?? "main"
        let selected = containers.first { $0.id == activeID }
            ?? containers.first { $0.makeView != nil }

        let chatView = ChatView(kernel: kernel)

        VStack(spacing: 0) {
            AppTitleToolbar(kernel: kernel)
            AppDivider()

            HStack(spacing: 0) {
                if kernel.layout?.isActivityBarVisible ?? true {
                    ActivityBar(kernel: kernel)
                    AppDivider(.vertical)
                }

                workspaceContent(selected: selected, chatView: chatView)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AppDivider()
            StatusBar(kernel: kernel)
        }
        .frame(minWidth: 1180, minHeight: 560)
        .background(theme.background)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func workspaceContent(
        selected: ViewContainerItem?,
        chatView: ChatView
    ) -> some View {
        let showContent = (kernel.layout?.isContentVisible ?? true) && selected?.makeView != nil
        let showChat = kernel.layout?.isChatVisible ?? true

        if showContent || showChat {
            HSplitView {
                SimpleRailView(kernel: kernel)
                    .frame(minWidth: 200, maxWidth: 300)

                if showContent, let makeView = selected?.makeView {
                    makeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if showChat {
                    chatView.privacySensitive()
                }
            }
        } else {
            HStack(spacing: 0) {
                SimpleRailView(kernel: kernel)
                    .frame(minWidth: 200, maxWidth: 300)

                if let makeView = selected?.makeView {
                    makeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}
