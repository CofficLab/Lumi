import AppKit
import LumiKernel
import LumiUI
import SwiftUI

/// 点击状态栏图标弹出的菜单:列出所有 `LumiMenuBarPopupItem`,
/// 并在底部提供「打开 Lumi / 检查更新 / 退出」操作行。
struct MenuBarPopupView: View {
    let colorScheme: ColorScheme
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)

                        if item.id != popupItems.last?.id {
                            Divider()
                        }
                    }
                }

                Divider()
            }

            MenuBarActionRow(title: "Open Lumi", systemImage: "macwindow", action: onShowMainWindow)
            Divider().padding(.leading, 36)
            MenuBarActionRow(title: "Check for Updates", systemImage: "arrow.down.circle", action: onCheckForUpdates)
            Divider().padding(.leading, 36)
            MenuBarActionRow(title: "Quit Lumi", systemImage: "power", action: onQuit)
        }
        .frame(width: 280)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(colorScheme)
    }
}

/// 弹出菜单中的单行操作按钮。
private struct MenuBarActionRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
