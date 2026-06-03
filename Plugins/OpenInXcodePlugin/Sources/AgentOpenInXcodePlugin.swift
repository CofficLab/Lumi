import AppKit
import LumiCoreKit
import SuperLogKit
import LumiUI
import SwiftUI
import Foundation
import os

/// 在 Xcode 中打开项目插件
///
/// 在 Agent 模式的状态栏左侧添加图标，点击后在 Xcode 中打开当前项目。
public actor AgentOpenInXcodePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    public nonisolated static let emoji = "💻"

    public nonisolated static let verbose: Bool = true

    public static let id: String = "AgentOpenInXcode"
    public static let displayName: String = String(localized: "Open in Xcode", bundle: .module)
    public static let description: String = String(localized: "Displays a button in the header to open the current project in Xcode", bundle: .module)
    public static let iconName: String = "hammer"
    public static var category: PluginCategory { .integration }
    public static var order: Int { 95 }
    public static let policy: PluginPolicy = .disabled

    // MARK: - Instance

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = AgentOpenInXcodePlugin()

    // MARK: - Status Bar

    /// 添加状态栏左侧视图
    @MainActor
    public func addStatusBarLeadingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        return AnyView(OpenInXcodeStatusBarView())
    }
}

private enum XcodeOpener {
    static func open(_ url: URL) {
        let workspace = NSWorkspace.shared
        let xcodeURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.dt.Xcode")
            ?? URL(fileURLWithPath: "/Applications/Xcode.app")
        let configuration = NSWorkspace.OpenConfiguration()
        workspace.open([url], withApplicationAt: xcodeURL, configuration: configuration)
    }
}

// MARK: - Status Bar View

/// Xcode 打开状态栏视图
public struct OpenInXcodeStatusBarView: View {
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
            detailView: OpenInXcodeDetailView(),
            id: "open-in-xcode-status"
        ) {
            Button(action: {
                openInXcode()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .font(.appCaption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(String(localized: "在 Xcode 中打开当前项目", bundle: .module))
        }
    }

    /// 无项目时的视图
    private var emptyView: some View {
        HStack(spacing: 6) {
            Image(systemName: "hammer.fill")
                .font(.appMicro)

            Text(String(localized: "Xcode", bundle: .module))
                .font(.appMicro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(theme.textSecondary.opacity(0.5))
        .help(String(localized: "无项目", bundle: .module))
    }

    private func openInXcode() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        XcodeOpener.open(url)
    }
}

// MARK: - Detail View

/// Xcode 打开详情视图（在 popover 中显示）
public struct OpenInXcodeDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Text(String(localized: "Xcode", bundle: .module))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button(action: {
                    openInXcode()
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

    private func openInXcode() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        XcodeOpener.open(url)
    }
}
