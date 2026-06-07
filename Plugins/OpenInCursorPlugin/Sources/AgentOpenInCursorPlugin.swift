import LumiCoreKit
import LumiUI
import AppKit
import SwiftUI

/// 在 Cursor 中打开项目插件
///
/// 在 Agent 模式的状态栏左侧添加图标，点击后在 Cursor 编辑器中打开当前项目。
public actor AgentOpenInCursorPlugin: SuperPlugin {
    public nonisolated static let emoji = "↗️"
    public nonisolated static let verbose: Bool = false
    public static let id = "AgentOpenInCursor"
    public static let displayName = String(localized: "Open in Cursor", bundle: .module)
    public static let description = String(localized: "Open current project in Cursor editor", bundle: .module)
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static var category: PluginCategory { .integration }
    public static var order: Int { 82 }

    /// 始终启用，用户不可关闭
    public static let policy: PluginPolicy = .optOut

    public static let shared = AgentOpenInCursorPlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - Status Bar

    /// 添加状态栏左侧视图
    @MainActor
    public func addStatusBarLeadingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        return AnyView(OpenInCursorStatusBarView())
    }
}

private enum CursorOpener {
    static func open(_ url: URL) {
        let workspace = NSWorkspace.shared
        guard let appURL = workspace.urlForApplication(withBundleIdentifier: "com.todesktop.230313mzl4w4u92")
            ?? (FileManager.default.fileExists(atPath: "/Applications/Cursor.app")
                ? URL(fileURLWithPath: "/Applications/Cursor.app")
                : nil)
        else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.open([url], withApplicationAt: appURL, configuration: configuration)
    }
}

// MARK: - Status Bar View

/// Cursor 打开状态栏视图
public struct OpenInCursorStatusBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM

    public var body: some View {
        Group {
            if projectVM.currentProjectPath.isEmpty {
                emptyView
            } else {
                hasProjectView
            }
        }
    }

    /// 有项目时的视图
    private var hasProjectView: some View {
        StatusBarHoverContainer(
            detailView: OpenInCursorDetailView(),
            id: "open-in-cursor-status"
        ) {
            Button(action: {
                openInCursor()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.appCaption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(String(localized: "在 Cursor 中打开当前项目", bundle: .module))
        }
    }

    /// 无项目时的视图
    private var emptyView: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.appMicro)

            Text(String(localized: "Cursor", bundle: .module))
                .font(.appMicro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(theme.textSecondary.opacity(0.5))
        .help(String(localized: "无项目", bundle: .module))
    }

    private func openInCursor() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        CursorOpener.open(url)
    }
}

// MARK: - Detail View

/// Cursor 打开详情视图（在 popover 中显示）
public struct OpenInCursorDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.appBodyEmphasized)

                Text(String(localized: "Cursor", bundle: .module))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button(action: {
                    openInCursor()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text(String(localized: "打开", bundle: .module))
                    }
                    .font(.appCaption)
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // 项目路径显示
            HStack(spacing: 8) {
                Text(String(localized: "项目", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 50, alignment: .leading)

                Text(projectVM.currentProjectPath)
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(projectVM.currentProjectPath, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.appCaption)
                }
                .buttonStyle(.plain)
                .help(String(localized: "复制路径", bundle: .module))
            }
        }
        .padding()
        .frame(width: 320)
    }

    private func openInCursor() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        CursorOpener.open(url)
    }
}
