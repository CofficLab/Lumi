import LumiCoreKit
import LumiUI
import AppKit
import SwiftUI

/// 在 GitHub Desktop 中打开项目插件
///
/// 在 Agent 模式的状态栏左侧添加图标，点击后在 GitHub Desktop 中打开当前项目。
/// 
/// ## 实现方式
///
/// 使用 OpenInKit 提供的 `URL.openInGitHubDesktop()` 方法：
/// - 首选 URL Scheme: `github-desktop://openLocalRepo?path=...`
/// - 回退方案: 通过 Bundle ID `com.github.GitHubClient` 打开应用
///
/// ## 注意事项
///
/// 如果用户未安装 GitHub Desktop，按钮会被禁用或无响应。
actor AgentOpenInGitHubDesktopPlugin: SuperPlugin {
    nonisolated static let emoji = "🐙"
    nonisolated static let verbose: Bool = true
    static let id = "AgentOpenInGitHubDesktop"
    static let displayName = String(localized: "Open in GitHub Desktop", table: "AgentOpenInGitHubDesktop")
    static let description = String(localized: "Open current project in GitHub Desktop", table: "AgentOpenInGitHubDesktop")
    static let iconName = "desktopcomputer"
    static var category: PluginCategory { .integration }
    static var order: Int { 97 }
    static let policy: PluginPolicy = .optIn

    /// 用户可在设置中启用/禁用此插件

    static let shared = AgentOpenInGitHubDesktopPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Status Bar

    /// 添加状态栏左侧视图
    @MainActor
    func addStatusBarLeadingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(OpenInGitHubDesktopStatusBarView())
    }
}

// MARK: - Status Bar View

/// GitHub Desktop 打开状态栏视图
struct OpenInGitHubDesktopStatusBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM

    var body: some View {
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
            detailView: OpenInGitHubDesktopDetailView(),
            id: "open-in-github-desktop-status"
        ) {
            Button(action: {
                openInGitHubDesktop()
            }) {
                HStack(spacing: 6) {
                    Image.githubDesktopApp
                        .resizable()
                        .frame(width: 12, height: 12)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(String(localized: "在 GitHub Desktop 中打开当前项目", table: "AgentOpenInGitHubDesktop"))
        }
    }

    /// 无项目时的视图
    private var emptyView: some View {
        HStack(spacing: 6) {
            Image.githubDesktopApp
                .resizable()
                .frame(width: 10, height: 10)

            Text(String(localized: "GitHub Desktop", table: "OpenInGitHubDesktopPlugin"))
                .font(.appMicro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(theme.textSecondary.opacity(0.5))
        .help(String(localized: "无项目", table: "AgentOpenInGitHubDesktop"))
    }

    private func openInGitHubDesktop() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        url.openInGitHubDesktop()
    }
}

// MARK: - Detail View

/// GitHub Desktop 打开详情视图（在 popover 中显示）
struct OpenInGitHubDesktopDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "desktopcomputer")
                    .font(.appBodyEmphasized)

                Text(String(localized: "GitHub Desktop", table: "OpenInGitHubDesktopPlugin"))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button(action: {
                    openInGitHubDesktop()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text(String(localized: "打开", table: "OpenInGitHubDesktopPlugin"))
                    }
                    .font(.appCaption)
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // 项目路径显示
            HStack(spacing: 8) {
                Text(String(localized: "项目", table: "OpenInGitHubDesktopPlugin"))
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
                .help(String(localized: "复制路径", table: "OpenInGitHubDesktopPlugin"))
            }
        }
        .padding()
        .frame(width: 320)
    }

    private func openInGitHubDesktop() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        url.openInGitHubDesktop()
    }
}