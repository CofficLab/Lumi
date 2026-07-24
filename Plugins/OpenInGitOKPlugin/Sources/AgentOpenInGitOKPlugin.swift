import AppKit
import LumiKernel
import LumiUI
import os
import SwiftUI

private let gitOKPluginLogger = Logger(subsystem: "com.coffic.lumi", category: "plugin.open-in-gitok")

/// 在 GitOK 中打开项目插件
///
/// 在状态栏添加图标，点击后在 GitOK 中打开当前项目。当前项目路径由内核的
/// `ProjectProviding` 提供（响应式）。
@MainActor
public final class AgentOpenInGitOKPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.open-in-gitok"
    public let name = "Open in GitOK"
    public let order = 98
    public let policy: LumiPluginPolicy = .optOut

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}
    public func onReady(kernel: LumiKernel) async throws {}

    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        guard let project = kernel.project else { return [] }
        return [
            StatusBarItem(
                id: "\(id).status",
                title: name,
                systemImage: "point.topleft.down.curvedto.point.filled.bottomright.up",
                placement: .leading,
                statusBarView: {
                    OpenInGitOKStatusBarView(project: project)
                }
            )
        ]
    }

    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(name)
                    .font(.title2.weight(.semibold))
                Text("Open current project in GitOK")
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
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

// MARK: - Status Bar View

/// GitOK 打开状态栏视图
public struct OpenInGitOKStatusBarView: View {
    @LumiTheme private var theme: any LumiUITheme
    @StateObject private var observer: ProjectPathObserver
    @State private var isGitOKInstalled: Bool = false

    public init(project: any ProjectProviding) {
        self._observer = StateObject(wrappedValue: ProjectPathObserver(project: project))
    }

    private var currentProjectPath: String {
        observer.path
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
            detailView: OpenInGitOKDetailView(path: currentProjectPath),
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
        guard !currentProjectPath.isEmpty else { return }
        let projectURL = URL(fileURLWithPath: currentProjectPath)
        GitOKLauncher.openProject(projectURL)
    }
}

// MARK: - Detail View

/// GitOK 打开详情视图（在 popover 中显示）
public struct OpenInGitOKDetailView: View {
    @LumiTheme private var theme: any LumiUITheme
    let path: String
    @State private var isGitOKInstalled: Bool = false

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

                Text(path)
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
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
        guard !path.isEmpty else { return }
        let projectURL = URL(fileURLWithPath: path)
        GitOKLauncher.openProject(projectURL)
    }
}
