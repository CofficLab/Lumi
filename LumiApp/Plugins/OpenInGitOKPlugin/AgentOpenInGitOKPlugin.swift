import AppKit
import MagicKit
import SwiftUI

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
actor AgentOpenInGitOKPlugin: SuperPlugin {
    nonisolated static let emoji = "✅"
    nonisolated static let verbose: Bool = false
    static let id = "AgentOpenInGitOK"
    static let displayName = String(localized: "Open in GitOK", table: "AgentOpenInGitOK")
    static let description = String(localized: "Open current project in GitOK", table: "AgentOpenInGitOK")
    static let iconName = "point.topleft.down.curvedto.point.filled.bottomright.up"
    static var order: Int { 98 }

    /// 用户可在设置中启用/禁用此插件
    static var isConfigurable: Bool { true }

    static let enable: Bool = true

    static let shared = AgentOpenInGitOKPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Status Bar

    /// 添加状态栏左侧视图
    @MainActor
    func addStatusBarLeadingView(activeIcon: String?) -> AnyView? {
        return AnyView(OpenInGitOKStatusBarView())
    }
}

// MARK: - Status Bar View

/// GitOK 打开状态栏视图
struct OpenInGitOKStatusBarView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @State private var isGitOKInstalled: Bool = false

    var body: some View {
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

            Text("GitOK")
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(.secondary.opacity(0.5))
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
struct OpenInGitOKDetailView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @State private var isGitOKInstalled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 标题
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image.gitokApp
                    .resizable()
                    .frame(width: 16, height: 16)

                Text("GitOK")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

                Button(action: {
                    openInGitOK()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("打开")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // 项目路径显示
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("项目")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    .frame(width: 50, alignment: .leading)

                Text(projectVM.currentProjectPath)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(projectVM.currentProjectPath, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("复制路径")
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
enum GitOKLauncher {
    /// GitOK 的 Bundle ID
    static let bundleID = "com.yueyi.GitOK"

    /// 检查 GitOK 是否已安装
    static func isInstalled() -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    /// 在 GitOK 中打开项目
    /// 使用与 GitHub Desktop 插件完全相同的 API：
    /// `NSWorkspace.shared.open([folderURL], withApplicationAt:appURL, configuration:)`
    /// 将项目文件夹作为 document 传给 GitOK，macOS 会自动处理全屏 Space 切换。
    /// - Parameter projectURL: 项目目录 URL
    static func openProject(_ projectURL: URL) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            AppLogger.core.error("GitOK 未安装")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([projectURL], withApplicationAt: appURL, configuration: config) { _, error in
            if let error {
                AppLogger.core.error("在 GitOK 中打开项目失败: \(error.localizedDescription)")
            }
        }
    }
}
