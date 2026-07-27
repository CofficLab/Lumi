import LumiKernel
import LumiLocalizationKit
import LumiUI
import SwiftUI

struct MenuBarPopupView: View {
    @LumiTheme private var theme

    let popupItems: [LumiMenuBarPopupItem]
    let onShowMainWindow: () -> Void
    let onCheckForUpdates: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if !popupItems.isEmpty {
                VStack(spacing: 0) {
                    ForEach(popupItems) { item in
                        item.makeView()
                            .frame(maxWidth: .infinity)
                            .fixedSize(horizontal: false, vertical: true)

                        if item.id != popupItems.last?.id {
                            GlassDivider()
                        }
                    }
                }

                GlassDivider()
            }

            appActionsSection
        }
        .frame(width: 300)
        .appSurface(style: .popover, cornerRadius: 0)
    }

    private var appActionsSection: some View {
        VStack(spacing: 0) {
            MenuBarActionRow(
                title: LumiLocalization.string("Open Lumi", bundle: .module),
                icon: "macwindow",
                color: theme.primary,
                action: onShowMainWindow
            )

            GlassDivider()
                .padding(.leading, 36)

            MenuBarActionRow(
                title: LumiLocalization.string("Check for Updates", bundle: .module),
                icon: "arrow.down.circle",
                color: theme.primary,
                action: onCheckForUpdates
            )

            GlassDivider()
                .padding(.leading, 36)

            MenuBarActionRow(
                title: LumiLocalization.string("Quit Lumi", bundle: .module),
                icon: "power",
                color: theme.error,
                action: onQuit
            )
        }
        .padding(.vertical, 4)
    }
}
