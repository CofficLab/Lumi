import AppKit
import LumiCoreKit
import LumiUI
import os
import SuperLogKit
import SwiftUI

private let gitOKPluginLogger = Logger(subsystem: "com.coffic.lumi", category: "plugin.open-in-gitok")

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
public enum AgentOpenInGitOKPlugin: LumiPlugin, SuperLog {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.open-in-gitok",
        displayName: LumiPluginLocalization.string("Open in GitOK", bundle: .module),
        description: LumiPluginLocalization.string("Open current project in GitOK", bundle: .module),
        order: 98,
        category: .general,
        policy: .optOut,
        stage: .beta,
        iconName: "point.topleft.down.curvedto.point.filled.bottomright.up",
    )

    @MainActor
    public static func statusBarItems(context: any LumiCoreAccessing) -> [LumiStatusBarItem] {
        guard let lumiCore = context.lumiCore else { return [] }
        return [
            LumiStatusBarItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName,
                placement: .leading,
                statusBarView: {
                    OpenInGitOKStatusBarView(lumiCore: lumiCore)
                }
            ),
        ]
    }

    @MainActor
    public static func pluginAboutView(context: any LumiCoreAccessing) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(info.displayName)
                    .font(.title2.weight(.semibold))
                Text(info.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }
}

// MARK: - Status Bar View

/// GitOK 打开状态栏视图
public struct OpenInGitOKStatusBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing

    @State private var isGitOKInstalled: Bool = false

    private var currentProjectPath: String {
        lumiCore.projectComponent.currentProject?.path ?? ""
    }

    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    public var body: some View {
        Group {
            if currentProjectPath.isEmpty {
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
            detailView: OpenInGitOKDetailView(lumiCore: lumiCore),
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
                ? LumiPluginLocalization.string("在 GitOK 中打开当前项目", bundle: .module)
                : LumiPluginLocalization.string("GitOK 未安装", bundle: .module))
        }
    }

    /// 无项目时的视图
    private var emptyView: some View {
        HStack(spacing: 6) {
            Image.gitokApp
                .resizable()
                .frame(width: 10, height: 10)

            Text(LumiPluginLocalization.string("GitOK", bundle: .module))
                .font(.appMicro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(theme.textSecondary.opacity(0.5))
        .help(LumiPluginLocalization.string("无项目", bundle: .module))
    }

    private func openInGitOK() {
        guard let path = lumiCore.projectComponent.currentProject?.path, !path.isEmpty else { return }
        let projectPath = lumiCore.projectComponent.currentProject?.path ?? ""
        let projectURL = URL(fileURLWithPath: projectPath)
        GitOKLauncher.openProject(projectURL)
    }
}

// MARK: - Detail View

/// GitOK 打开详情视图（在 popover 中显示）
public struct OpenInGitOKDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing

    @State private var isGitOKInstalled: Bool = false

    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image.gitokApp
                    .resizable()
                    .frame(width: 16, height: 16)

                Text(LumiPluginLocalization.string("GitOK", bundle: .module))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button(action: {
                    openInGitOK()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text(LumiPluginLocalization.string("打开", bundle: .module))
                    }
                    .font(.appCaption)
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // 项目路径显示
            HStack(spacing: 8) {
                Text(LumiPluginLocalization.string("项目", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 50, alignment: .leading)

                Text(lumiCore.projectComponent.currentProject?.path ?? "")
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(lumiCore.projectComponent.currentProject?.path ?? "", forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.appCaption)
                }
                .buttonStyle(.plain)
                .help(LumiPluginLocalization.string("复制路径", bundle: .module))
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            isGitOKInstalled = GitOKLauncher.isInstalled()
        }
    }

    private func openInGitOK() {
        guard let path = lumiCore.projectComponent.currentProject?.path, !path.isEmpty else { return }
        let projectPath = lumiCore.projectComponent.currentProject?.path ?? ""
        let projectURL = URL(fileURLWithPath: projectPath)
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
            gitOKPluginLogger.error("GitOK is not installed")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([projectURL], withApplicationAt: appURL, configuration: config) { _, error in
            if let error {
                gitOKPluginLogger.error("Failed to open project in GitOK: \(error.localizedDescription)")
            }
        }
    }
}
