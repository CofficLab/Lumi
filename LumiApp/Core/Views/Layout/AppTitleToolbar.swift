import AppKit
import LumiUI
import SwiftUI

/// Self-rendered title toolbar for the main window.
///
/// The plugin contribution points stay the same as the old system toolbar:
/// leading, center, and trailing views are collected by `AppPluginVM`.
struct AppTitleToolbar: View {
    @EnvironmentObject private var pluginProvider: AppPluginVM
    @EnvironmentObject private var layoutVM: WindowLayoutVM
    @EnvironmentObject private var themeVM: AppThemeVM

    private let height: CGFloat = 44
    private let trafficLightReserveWidth: CGFloat = 76

    var body: some View {
        let activeIcon = layoutVM.activeViewContainerIcon
        let leadingViews = pluginProvider.getToolbarLeadingViews(activeIcon: activeIcon)
        let centerViews = pluginProvider.getToolbarCenterViews(activeIcon: activeIcon)
        let trailingViews = pluginProvider.getToolbarTrailingViews(activeIcon: activeIcon)
        let theme = themeVM.activeChromeTheme

        ZStack {
            WindowDragRegion()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 8) {
                Color.clear
                    .frame(width: trafficLightReserveWidth, height: height)
                    .accessibilityHidden(true)

                toolbarGroup(leadingViews, idPrefix: "title_toolbar_leading")

                Spacer(minLength: 12)

                toolbarGroup(trailingViews, idPrefix: "title_toolbar_trailing")
            }
            .padding(.trailing, 12)

            toolbarGroup(centerViews, idPrefix: "title_toolbar_center")
                .frame(maxWidth: 420)
                .padding(.horizontal, trafficLightReserveWidth + 12)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .foregroundColor(theme.workspaceTextColor())
        .background(theme.sidebarBackgroundColor())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.statusBarDividerColor())
                .frame(height: 1)
        }
    }

    private func toolbarGroup(_ views: [AnyView], idPrefix: String) -> some View {
        HStack(spacing: 8) {
            ForEach(views.indices, id: \.self) { index in
                views[index]
                    .id("\(idPrefix)_\(index)")
            }
        }
        .frame(height: height)
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

#Preview("App Title Toolbar") {
    AppTitleToolbar()
        .inRootView(container: WindowContainer(container: RootContainer.shared))
        .frame(width: 900)
}
