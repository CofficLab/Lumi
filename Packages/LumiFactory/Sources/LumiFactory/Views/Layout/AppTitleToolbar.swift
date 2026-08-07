import AppKit
import LumiKernel
import LumiUI
import SwiftUI

struct AppTitleToolbar: View {
    @LumiTheme private var theme
    let kernel: LumiKernel

    // 不订阅 workspace 服务的 `objectWillChange`（无需 `ObservableWorkspaceBox` 包装），
    // 改为「快照 + 事件刷新」：init 读一次初值，监听 `.workspaceContributionsDidChange`
    // 重新拉取 titleToolbarItems。
    @State private var items: [TitleToolbarItem] = []

    private let height: CGFloat = 44
    private let trafficLightReserveWidth: CGFloat = 76

    init(kernel: LumiKernel) {
        self.kernel = kernel
        _items = State(initialValue: kernel.workspace?.allTitleToolbarItems ?? [])
    }

    var body: some View {
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
        .onWorkspaceContributionsDidChange {
            items = kernel.workspace?.allTitleToolbarItems ?? []
        }
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
