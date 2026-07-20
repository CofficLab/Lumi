import AppKit
import LumiKernel
import LumiUI
import SwiftUI

struct AppTitleToolbar: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

    private let height: CGFloat = 44
    private let trafficLightReserveWidth: CGFloat = 76

    var body: some View {
        let items = kernel.titleToolbar?.allTitleToolbarItems ?? []
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
        .background(.red)
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
