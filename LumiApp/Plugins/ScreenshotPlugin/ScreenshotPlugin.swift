import MagicKit
import SwiftUI
import os

/// 截图插件
///
/// 在右侧栏底部工具栏注入区域截图按钮。
/// 点击后启动全屏截图选区流程（ScreenshotState），
/// 截图完成后通过 `.screenshotCaptured` 通知广播，
/// 由 ChatAttachmentPlugin 消费并添加为附件。
actor ScreenshotPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.screenshot")

    nonisolated static let emoji = "📸"
    nonisolated static let verbose: Bool = false
    static let id = "Screenshot"
    static let displayName = String(localized: "Screenshot", table: "AgentChat")
    static let description = String(localized: "Capture screen region as chat attachment", table: "AgentChat")
    static let iconName = "crop"
    static var order: Int { 85 }
    nonisolated static let enable: Bool = true
    static let shared = ScreenshotPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Sidebar Toolbar

    @MainActor func addSidebarLeadingToolbarItems(activeIcon: String?) -> [SidebarToolbarItem] {
        guard activeIcon == EditorPlugin.iconName else { return [] }
        return [
            SidebarToolbarItem(
                id: "screenshot",
                title: String(localized: "Screenshot Region", table: "AgentChat"),
                systemImage: "crop",
                priority: 30
            )
        ]
    }

    @MainActor func addSidebarToolbarItemView(itemId: String, activeIcon: String?) -> AnyView? {
        guard itemId == "screenshot" else { return nil }
        return AnyView(ScreenshotToolbarButton())
    }
}

// MARK: - Toolbar Button View

/// 截图工具栏按钮
///
/// 点击启动截图选区流程，截图中显示加载指示器。
private struct ScreenshotToolbarButton: View {
    @EnvironmentObject private var themeVM: AppThemeVM
    @StateObject private var screenshotState = ScreenshotState.shared

    var body: some View {
        Button(action: {
            screenshotState.startCapture()
        }) {
            Group {
                if screenshotState.isPreparing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "crop")
                        .font(.system(size: 13))
                }
            }
            .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            .frame(width: 28, height: 28)
            .background(themeVM.activeAppTheme.workspaceTextColor().opacity(0.06))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(screenshotState.isCapturing)
        .help(helpText)
        .keyboardShortcut("S", modifiers: [.command, .shift])
        .accessibilityLabel(String(localized: "Screenshot Region", table: "AgentChat"))
        .accessibilityHint(String(localized: "Screenshot Region Hint", table: "AgentChat"))
    }

    private var helpText: String {
        if screenshotState.isPreparing {
            return String(localized: "Preparing Screenshot", table: "AgentChat")
        }
        return String(localized: "Screenshot Region", table: "AgentChat")
    }
}
