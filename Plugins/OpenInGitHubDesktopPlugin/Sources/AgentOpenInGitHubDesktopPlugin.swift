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
public enum AgentOpenInGitHubDesktopPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.open-in-github-desktop",
        displayName: LumiPluginLocalization.string("Open in GitHub Desktop", bundle: .module),
        description: LumiPluginLocalization.string("Open current project in GitHub Desktop", bundle: .module),
        order: 97,
        category: .general,
        policy: .optOut,
        stage: .beta,
        iconName: "desktopcomputer",
    )

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard let lumiCore = context.lumiCore else { return [] }
        return [
            LumiStatusBarItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName,
                placement: .leading,
                statusBarView: {
                    OpenInGitHubDesktopStatusBarView(lumiCore: lumiCore)
                }
            )
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
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

private enum GitHubDesktopOpener {
    static func open(_ url: URL) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.github.GitHubClient") else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
    }
}

// MARK: - Status Bar View

/// GitHub Desktop 打开状态栏视图
public struct OpenInGitHubDesktopStatusBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing

    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    private var currentProjectPath: String {
        lumiCore.projectState?.currentProject?.path ?? ""
    }

    public var body: some View {
        Group {
            if currentProjectPath.isEmpty {
                emptyView
            } else {
                hasProjectView
            }
        }
    }

    /// 有项目时的视图
    private var hasProjectView: some View {
        StatusBarHoverContainer(
            detailView: OpenInGitHubDesktopDetailView(lumiCore: lumiCore),
            id: "open-in-github-desktop-status"
        ) {
            Button(action: {
                openInGitHubDesktop()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "desktopcomputer")
                        .font(.appCaption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(LumiPluginLocalization.string("在 GitHub Desktop 中打开当前项目", bundle: .module))
        }
    }

    /// 无项目时的视图
    private var emptyView: some View {
        HStack(spacing: 6) {
            Image(systemName: "desktopcomputer")
                .font(.appMicro)

            Text(LumiPluginLocalization.string("GitHub Desktop", bundle: .module))
                .font(.appMicro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(theme.textSecondary.opacity(0.5))
        .help(LumiPluginLocalization.string("无项目", bundle: .module))
    }

    private func openInGitHubDesktop() {
        guard !currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: currentProjectPath)
        GitHubDesktopOpener.open(url)
    }
}

// MARK: - Detail View

/// GitHub Desktop 打开详情视图（在 popover 中显示）
public struct OpenInGitHubDesktopDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing

    public init(lumiCore: LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    private var currentProjectPath: String {
        lumiCore.projectState?.currentProject?.path ?? ""
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "desktopcomputer")
                    .font(.appBodyEmphasized)

                Text(LumiPluginLocalization.string("GitHub Desktop", bundle: .module))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button(action: {
                    openInGitHubDesktop()
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

                Text(currentProjectPath)
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(currentProjectPath, forType: .string)
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
    }

    private func openInGitHubDesktop() {
        guard !currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: currentProjectPath)
        GitHubDesktopOpener.open(url)
    }
}
