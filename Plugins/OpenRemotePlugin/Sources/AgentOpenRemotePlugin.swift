import AppKit
import Foundation
import LumiKernel
import LumiUI
import os
import ShellKit
import SwiftUI

/// 在浏览器中打开远程仓库插件
///
/// 在状态栏添加图标，点击后在浏览器中打开当前项目的远程仓库地址。
/// 当前项目路径由内核的 `ProjectProviding` 提供（响应式）。
@MainActor
public final class AgentOpenRemotePlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.open-remote")

    public let id = "com.coffic.lumi.plugin.open-remote"
    public let name = "Open Remote Repository"
    public let order = 62
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
                systemImage: "safari",
                placement: .leading,
                statusBarView: {
                    OpenRemoteStatusBarView(project: project)
                }
            )
        ]
    }

    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(name)
                    .font(.title2.weight(.semibold))
                Text("Displays a button in the header to open the current project's remote repository in browser")
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

// MARK: - Status Bar View

/// 远程仓库状态栏视图
public struct OpenRemoteStatusBarView: View {
    @LumiTheme private var theme: any LumiUITheme
    @StateObject private var observer: ProjectPathObserver

    @State private var remoteURL: URL?
    @State private var isLoading = false
    @State private var lastResolvedPath: String = ""

    public init(project: any ProjectProviding) {
        self._observer = StateObject(wrappedValue: ProjectPathObserver(project: project))
    }

    private var currentProjectPath: String {
        observer.path
    }

    public var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let url = remoteURL {
                hasRemoteView(url: url)
            } else {
                noRemoteView
            }
        }
        .onAppear {
            updateRemoteURL()
        }
        .onChange(of: currentProjectPath) { _, _ in
            updateRemoteURL()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            updateRemoteURL()
        }
    }

    /// 加载视图
    private var loadingView: some View {
        StatusBarHoverContainer(
            detailView: OpenRemoteDetailView(url: nil),
            id: "open-remote-status"
        ) {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 10, height: 10)

                Text(LumiPluginLocalization.string("加载中...", bundle: .module))
                    .font(.appMicro)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(theme.textSecondary)
        }
    }

    /// 有远程仓库的视图
    private func hasRemoteView(url: URL) -> some View {
        StatusBarHoverContainer(
            detailView: OpenRemoteDetailView(url: url),
            id: "open-remote-status"
        ) {
            Button(action: {
                openInBrowser()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "safari")
                        .font(.appCaption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(LumiPluginLocalization.string("在浏览器中打开远程仓库", bundle: .module))
        }
    }

    /// 无远程仓库的视图
    private var noRemoteView: some View {
        HStack(spacing: 6) {
            Image(systemName: "safari")
                .font(.appMicro)

            Text(LumiPluginLocalization.string("无远程仓库", bundle: .module))
                .font(.appMicro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(theme.textSecondary.opacity(0.5))
        .help(LumiPluginLocalization.string("无远程仓库", bundle: .module))
    }

    private func updateRemoteURL() {
        let path = currentProjectPath
        // 避免对同一路径重复解析
        guard path != lastResolvedPath else { return }
        lastResolvedPath = path

        guard !path.isEmpty else {
            remoteURL = nil
            isLoading = false
            return
        }

        isLoading = true

        Task {
            let url = await fetchRemoteURL(for: path)

            // 仅当仍在解析同一路径时才应用结果
            guard lastResolvedPath == path else { return }

            remoteURL = url
            isLoading = false
        }
    }

    private func fetchRemoteURL(for projectPath: String) async -> URL? {
        let projectURL = URL(fileURLWithPath: projectPath)
        let gitDir = projectURL.appendingPathComponent(".git", isDirectory: true)

        // 检查是否是 Git 仓库
        guard FileManager.default.fileExists(atPath: gitDir.path) else {
            return nil
        }

        // 获取远程仓库地址
        guard let remoteURLString = await runGit(args: ["remote", "get-url", "origin"], in: projectURL) else {
            return nil
        }

        var formattedURL = remoteURLString.trimmingCharacters(in: .whitespacesAndNewlines)

        // 转换 SSH 格式为 HTTPS 格式
        // git@github.com:username/repo.git -> https://github.com/username/repo.git
        if formattedURL.hasPrefix("git@") {
            formattedURL = formattedURL.replacingOccurrences(of: ":", with: "/", range: formattedURL.range(of: ":"))
            formattedURL = formattedURL.replacingOccurrences(of: "git@", with: "https://")
        }

        // 移除 .git 后缀
        if formattedURL.hasSuffix(".git") {
            formattedURL = String(formattedURL.dropLast(4))
        }

        return URL(string: formattedURL)
    }

    private func runGit(args: [String], in directory: URL) async -> String? {
        let result = try? await ShellExecutor.execute(
            executable: "/usr/bin/git",
            arguments: args,
            options: ShellOptions(
                workingDirectory: directory.path,
                environment: [
                    "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                ],
                throwsOnError: false
            )
        )
        return result?.exitCode == 0 ? result?.stdout : nil
    }

    private func openInBrowser() {
        guard let url = remoteURL else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Detail View

/// 远程仓库详情视图（在 popover 中显示）
public struct OpenRemoteDetailView: View {
    @LumiTheme private var theme: any LumiUITheme

    public let url: URL?

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "safari")
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.primary)

                Text(LumiPluginLocalization.string("远程仓库", bundle: .module))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                if let url = url {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text(LumiPluginLocalization.string("打开", bundle: .module))
                        }
                        .font(.appCaption)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Divider()

            if let url = url {
                // URL 显示
                HStack(spacing: 8) {
                    Text(LumiPluginLocalization.string("URL", bundle: .module))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 60, alignment: .leading)

                    Text(url.absoluteString)
                        .font(.appMonoCaption)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    Spacer()

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.appCaption)
                    }
                    .buttonStyle(.plain)
                    .help(LumiPluginLocalization.string("复制 URL", bundle: .module))
                }
            } else {
                // 无远程仓库
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.appTitle)
                            .foregroundColor(theme.warning)

                        Text(LumiPluginLocalization.string("当前项目没有远程仓库", bundle: .module))
                            .font(.appCallout)
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            }
        }
        .padding()
        .frame(width: 320)
    }
}
