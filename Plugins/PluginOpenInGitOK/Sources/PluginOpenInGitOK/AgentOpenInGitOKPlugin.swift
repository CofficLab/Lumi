import LumiCoreKit
import LumiUI
import AppKit
import SwiftUI
import os

/// 在 GitOK 中打开项目插件
///
/// 在 Agent 模式的状态栏左侧添加图标，点击后在 GitOK 中打开当前项目。
/// 
/// ## 实现方式
///
/// 使用 NSWorkspace 的 `open(_:withApplicationAt:configuration:)` 将项目文件夹
/// 直接传给 GitOK 打开。这与 GitHub Desktop 插件使用完全相同的 API，
/// macOS 会自动处理全屏 Space 切换。
/// 
/// ## 注意事项
///
/// GitOK 必须已安装在系统中。如果未安装，按钮点击后会有错误日志输出。
public actor AgentOpenInGitOKPlugin: SuperPlugin {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.open-in-gitok")
    public nonisolated static let emoji = "✅"
    public nonisolated static let verbose: Bool = true
    public static let id = "AgentOpenInGitOK"
    public static let displayName = String(localized: "Open in GitOK", table: "AgentOpenInGitOK")
    public static let description = String(localized: "Open current project in GitOK", table: "AgentOpenInGitOK")
    public static let iconName = "point.topleft.down.curvedto.point.filled.bottomright.up"
    public static var category: PluginCategory { .integration }
    public static var order: Int { 98 }
    public static let policy: PluginPolicy = .alwaysOn

    /// 始终启用，用户不可关闭

    public static let shared = AgentOpenInGitOKPlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - Status Bar

    /// 添加状态栏左侧视图
    @MainActor
    public func addStatusBarLeadingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        return AnyView(OpenInGitOKStatusBarView())
    }
}

// MARK: - Status Bar View

/// GitOK 打开状态栏视图
public struct OpenInGitOKStatusBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM
    @State private var isGitOKInstalled: Bool = false

    public var body: some View {
        Group {
            if projectVM.currentProjectPath.isEmpty {
                emptyView
            } else {
                hasProjectView
            }
        }
        .onAppear {
            isGitOKInstalled = GitOKLauncher.isInstalled()
        }
    }

    /// 有项目时的视图
    private var hasProjectView: some View {
        StatusBarHoverContainer(
            detailView: OpenInGitOKDetailView(),
            id: "open-in-gitok-status"
        ) {
            Button(action: {
                openInGitOK()
            }) {
                HStack(spacing: 6) {
                    Image.gitokApp
                        .resizable()
                        .frame(width: 12, height: 12)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(isGitOKInstalled
                ? String(localized: "在 GitOK 中打开当前项目", table: "AgentOpenInGitOK")
                : String(localized: "GitOK 未安装", table: "AgentOpenInGitOK"))
        }
    }

    /// 无项目时的视图
    private var emptyView: some View {
        HStack(spacing: 6) {
            Image.gitokApp
                .resizable()
                .frame(width: 10, height: 10)

            Text(String(localized: "GitOK", table: "OpenInGitOKPlugin"))
                .font(.appMicro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(theme.textSecondary.opacity(0.5))
        .help(String(localized: "无项目", table: "AgentOpenInGitOK"))
    }

    private func openInGitOK() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let projectURL = URL(fileURLWithPath: projectVM.currentProjectPath)
        GitOKLauncher.openProject(projectURL)
    }
}

// MARK: - Detail View

/// GitOK 打开详情视图（在 popover 中显示）
public struct OpenInGitOKDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM
    @State private var isGitOKInstalled: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image.gitokApp
                    .resizable()
                    .frame(width: 16, height: 16)

                Text(String(localized: "GitOK", table: "OpenInGitOKPlugin"))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button(action: {
                    openInGitOK()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text(String(localized: "打开", table: "OpenInGitOKPlugin"))
                    }
                    .font(.appCaption)
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // 项目路径显示
            HStack(spacing: 8) {
                Text(String(localized: "项目", table: "OpenInGitOKPlugin"))
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
                .help(String(localized: "复制路径", table: "OpenInGitOKPlugin"))
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            isGitOKInstalled = GitOKLauncher.isInstalled()
        }
    }

    private func openInGitOK() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let projectURL = URL(fileURLWithPath: projectVM.currentProjectPath)
        GitOKLauncher.openProject(projectURL)
    }
}

// MARK: - GitOK Launcher

/// GitOK 打开逻辑（可被 StatusBarView 和 DetailView 共用）
public enum GitOKLauncher {
    /// GitOK 的 Bundle ID
    public static let bundleID = "com.yueyi.GitOK"

    /// 检查 GitOK 是否已安装
    public static func isInstalled() -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    /// 在 GitOK 中打开项目
    /// 使用与 GitHub Desktop 插件完全相同的 API：
    /// `NSWorkspace.shared.open([folderURL], withApplicationAt:appURL, configuration:)`
    /// 将项目文件夹作为 document 传给 GitOK，macOS 会自动处理全屏 Space 切换。
    /// - Parameter projectURL: 项目目录 URL
    public static func openProject(_ projectURL: URL) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            AgentOpenInGitOKPlugin.logger.error("GitOK 未安装")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([projectURL], withApplicationAt: appURL, configuration: config) { _, error in
            if let error {
                AgentOpenInGitOKPlugin.logger.error("在 GitOK 中打开项目失败: \(error.localizedDescription)")
            }
        }
    }
}
