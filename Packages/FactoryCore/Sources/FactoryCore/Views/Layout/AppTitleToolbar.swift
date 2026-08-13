import AppKit
import KernelLumi
import LumiUI
import SwiftUI

struct AppTitleToolbar: View {
    @LumiTheme private var theme
    let kernel: KernelLumi

    // 不订阅 workspace 服务的 `objectWillChange`，
    // 改为「快照 + 事件刷新」：init 读一次初值，监听 `.workspaceContributionsDidChange`
    // 重新拉取 titleToolbarItems。
    @State private var items: [TitleToolbarItem] = []

    private let height: CGFloat = 44
    private let trafficLightReserveWidth: CGFloat = 76

    init(kernel: KernelLumi) {
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
