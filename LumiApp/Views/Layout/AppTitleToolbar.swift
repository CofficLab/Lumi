import AppKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct AppTitleToolbar: View {
    @LumiTheme private var theme
    @ObservedObject var pluginService: PluginService
    let activeID: String
    let activeTitle: String
    let projectPathStore: LumiCurrentProjectPathStore

    private let height: CGFloat = 44
    private let trafficLightReserveWidth: CGFloat = 76

    var body: some View {
        let context = LumiPluginContext(
            activeSectionID: activeID,
            activeSectionTitle: activeTitle,
            dependencies: LumiPluginDependencies { dependencies in
                dependencies.register(LumiCurrentProjectPathStoring.self, projectPathStore)
            }
        )
        let items = pluginService.titleToolbarItems(context: context)
        let leadingItems = items.filter { $0.placement == .leading }
        let centerItems = items.filter { $0.placement == .center }
        let trailingItems = items.filter { $0.placement == .trailing }

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
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .foregroundStyle(theme.textPrimary)
        .appSurface(style: .toolbar, cornerRadius: 0)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.divider)
                .frame(height: 1)
        }
    }

    private func toolbarGroup(_ items: [LumiTitleToolbarItem]) -> some View {
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
