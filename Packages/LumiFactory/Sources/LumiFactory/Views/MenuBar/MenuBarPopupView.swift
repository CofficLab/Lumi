import LumiKernel
import LumiLocalizationKit
import LumiUI
import SwiftUI

struct MenuBarPopupView: View {
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
                            Divider()
                        }
                    }
                }

                Divider()
            }

            appActionsSection
        }
        .frame(width: 300)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(SystemAppearanceResolver.effectiveColorScheme)
    }

    private var appActionsSection: some View {
        VStack(spacing: 0) {
            MenuBarActionRow(
                title: LumiLocalization.string("Open Lumi", bundle: .module),
                icon: "macwindow",
                color: .accentColor,
                action: onShowMainWindow
            )

            Divider()
                .padding(.leading, 36)

            MenuBarActionRow(
                title: LumiLocalization.string("Check for Updates", bundle: .module),
                icon: "arrow.down.circle",
                color: .accentColor,
                action: onCheckForUpdates
            )

            Divider()
                .padding(.leading, 36)

            MenuBarActionRow(
                title: LumiLocalization.string("Quit Lumi", bundle: .module),
                icon: "power",
                color: .red,
                action: onQuit
            )
        }
        .padding(.vertical, 8)
    }
}
