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
                        // 每个插件 view 是 self-contained 区块,自行负责 padding / 背景。
                        item.makeView()
                            .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(width: 280)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(colorScheme)
    }

    private var appActionsSection: some View {
        VStack(spacing: 0) {
            MenuBarActionRow(
                title: "Open Lumi",
                icon: "macwindow",
                color: .accentColor,
                showCheckmark: false,
                action: onShowMainWindow
            )

            Divider()
                .padding(.leading, 36)

            MenuBarActionRow(
                title: "Check for Updates",
                icon: "arrow.down.circle",
                color: .accentColor,
                showCheckmark: false,
                action: onCheckForUpdates
            )

            Divider()
                .padding(.leading, 36)

            MenuBarActionRow(
                title: "Quit Lumi",
                icon: "power",
                color: .red,
                showCheckmark: false,
                action: onQuit
            )
        }
        .padding(.vertical, 8)
    }
}
