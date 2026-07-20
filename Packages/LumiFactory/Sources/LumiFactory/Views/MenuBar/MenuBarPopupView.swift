import LumiCoreMenuBar
import LumiKernel
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
                "打开 Lumi",
                icon: "macwindow",
                color: Color(hex: "7C6FFF"),
                action: onShowMainWindow
            )

            GlassDivider()
                .padding(.leading, 36)

            MenuBarActionRow(
                "检查更新",
                icon: "arrow.down.circle",
                color: Color(hex: "0A84FF"),
                action: onCheckForUpdates
            )

            GlassDivider()
                .padding(.leading, 36)

            MenuBarActionRow(
                "退出 Lumi",
                icon: "power",
                color: Color(hex: "FF453A"),
                action: onQuit
            )
        }
        .padding(.vertical, 4)
    }
}
