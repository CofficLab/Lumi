import LumiCoreKit
import SuperLogKit
import LumiUI
import SwiftUI
import os

/// 截图插件
///
/// 在右侧栏底部工具栏注入区域截图按钮。
/// 点击后启动全屏截图选区流程（ScreenshotState），
/// 截图完成后通过 `.screenshotCaptured` 通知广播，
/// 由 ChatAttachmentPlugin 消费并添加为附件。
public actor ScreenshotPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.screenshot")

    public nonisolated static let emoji = "📸"
    public nonisolated static let verbose: Bool = true
    public static let id = "Screenshot"
    public static let displayName = String(localized: "Screenshot", table: "AgentChat")
    public static let description = String(localized: "Capture screen region as chat attachment", table: "AgentChat")
    public static let iconName = "crop"
    public static var category: PluginCategory { .integration }
    public static var order: Int { 85 }
    public static let shared = ScreenshotPlugin()

    // MARK: - Lifecycle

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - Sidebar Toolbar

    @MainActor public func addSidebarLeadingToolbarItems(context: PluginContext) -> [SidebarToolbarItem] {
        guard context.supportsAIChat else { return [] }
        return [
            SidebarToolbarItem(
                id: "screenshot",
                title: String(localized: "Screenshot Region", table: "AgentChat"),
                systemImage: "crop",
                priority: 30
            )
        ]
    }

    @MainActor public func addSidebarToolbarItemView(itemId: String, context: PluginContext) -> AnyView? {
        guard itemId == "screenshot" else { return nil }
        return AnyView(ScreenshotToolbarButton())
    }
}

// MARK: - Toolbar Button View

/// 截图工具栏按钮
///
/// 点击启动截图选区流程，截图中显示加载指示器。
private struct ScreenshotToolbarButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @StateObject private var screenshotState = ScreenshotState.shared

    public var body: some View {
        sidebarToolbarButton(
            id: "screenshot",
            tooltip: helpText
        ) {
            screenshotState.startCapture()
        } content: {
            Group {
                if screenshotState.isPreparing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "crop")
                        .font(.appCaptionEmphasized)
                }
            }
            .foregroundColor(theme.textSecondary)
            .frame(width: 28, height: 28)
            .background(theme.textPrimary.opacity(0.06))
            .clipShape(Circle())
        }
        .disabled(screenshotState.isCapturing)
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
