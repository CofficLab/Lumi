import AppKit
import LumiKernel
import LumiUI
import SwiftUI

struct AppTitleToolbar: View {
    @LumiTheme private var theme
    let kernel: LumiKernel

    // 只订阅 workspace 这一个 service：本视图不挂在 kernel 全局总线上，
    // project/conversations/settings 等无关服务变更不会触发这里刷新。
    @StateObject private var workspaceBox = ObservableWorkspaceBox()

    private let height: CGFloat = 44
    private let trafficLightReserveWidth: CGFloat = 76

    var body: some View {
        let items = workspaceBox.service?.allTitleToolbarItems ?? []
        let leadingItems = items.filter { $0.placement == .leading }
        let centerItems = items.filter { $0.placement == .center }
        let trailingItems = items.filter { $0.placement == .trailing }

        AppToolbarContainer(height: height, backgroundStyle: .toolbar, padding: .init(top: 0, leading: 0, bottom: 0, trailing: 0)) {
            ZStack {
                WindowDragRegion()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 8) {
                    Color.clear
                        .frame(width: trafficLightReserveWidth, height: height)
                        .accessibilityHidden(true)

                    toolbarGroup(leadingItems)

                    Spacer(minLength: 12)

                    toolbarGroup(trailingItems)
                }
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

                toolbarGroup(centerItems)
                    .frame(maxWidth: 420)
                    .padding(.horizontal, trafficLightReserveWidth + 12)
            }
        }
        .foregroundStyle(theme.textPrimary)
        #if DEBUG
        // DEBUG 模式下叠加一层 warning 半透明色，提示当前为 Debug 构建。
        // Release 构建下整段不参与编译，零成本零干扰。
        .overlay(
            Rectangle()
                .fill(theme.warning.opacity(0.20))
                .allowsHitTesting(false)
        )
        #endif
        .task { workspaceBox.bind(kernel.workspace) }
    }

    private func toolbarGroup(_ items: [TitleToolbarItem]) -> some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                item.makeView()
                    .help(item.title)
            }
        }
        .frame(height: height)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> DragRegionView {
        DragRegionView()
    }

    func updateNSView(_ nsView: DragRegionView, context: Context) {}
}

private final class DragRegionView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }
}
