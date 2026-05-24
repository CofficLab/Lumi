import LumiUI
import SwiftUI

/// 快速启动器插件的菜单栏弹窗视图
struct QuickLauncherMenuBarPopupView: View {
    @State private var manager = QuickLauncherManager.shared

    var body: some View {
        HStack(spacing: 8) {
            ForEach(manager.apps) { app in
                AppIconButton(
                    name: app.name,
                    icon: app.icon,
                    action: { manager.launchApp(app) }
                )
            }
        }
        .padding(8)
    }
}

// MARK: - 应用图标按钮

private struct AppIconButton: View {
    let name: String
    let icon: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "0A84FF"))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering ? Color(hex: "0A84FF").opacity(0.15) : Color.adaptive(light: "F2F2F7", dark: "1C1C1E"))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview("Quick Launcher Menu Bar Popup") {
    QuickLauncherMenuBarPopupView()
        .padding()
}
