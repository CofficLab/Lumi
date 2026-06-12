import LumiCoreKit
import LumiUI
import SwiftUI

struct MenuBarPopupView: View {
    @LumiTheme private var theme

    let popupItems: [LumiMenuBarPopupItem]
    let onShowMainWindow: () -> Void
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

            menuItem("打开 Lumi", systemImage: "macwindow", action: onShowMainWindow)

            GlassDivider()

            menuItem("退出 Lumi", systemImage: "power", role: .destructive, action: onQuit)
        }
        .frame(width: 300)
        .appSurface(style: .popover, cornerRadius: 0)
    }

    private func menuItem(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                Text(title)
                    .font(.appCaption)
                Spacer()
            }
            .foregroundStyle(role == .destructive ? theme.error : theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
