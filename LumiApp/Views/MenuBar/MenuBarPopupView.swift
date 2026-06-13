import LumiCoreKit
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

            menuRow("打开 Lumi", systemImage: "macwindow", action: onShowMainWindow)

            GlassDivider()

            menuRow("检查更新", systemImage: "arrow.down.circle", action: onCheckForUpdates)

            GlassDivider()

            menuRow("退出 Lumi", systemImage: "power", role: .destructive, action: onQuit)
        }
        .frame(width: 300)
        .appSurface(style: .popover, cornerRadius: 0)
    }

    private func menuRow(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            if let role {
                AppContextMenuRow(titleKey, systemImage: systemImage, role: role, action: action)
            } else {
                AppContextMenuRow(titleKey, systemImage: systemImage, action: action)
            }
        }
        .font(.appCaption)
        .foregroundStyle(role == .destructive ? theme.error : theme.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
