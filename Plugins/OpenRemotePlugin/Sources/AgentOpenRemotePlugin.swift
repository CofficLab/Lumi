import LumiCoreKit
import SuperLogKit
import LumiUI
import AppKit
import SwiftUI
import Foundation
import os
import ShellKit

/// 在浏览器中打开远程仓库插件
///
/// 在 Agent 模式的状态栏添加一个图标，点击后在浏览器中打开当前项目的远程仓库地址。
public enum AgentOpenRemotePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optOut
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "safari"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.open-remote")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.open-remote",
        displayName: LumiPluginLocalization.string("Open Remote Repository", bundle: .module),
        description: LumiPluginLocalization.string("Displays a button in the header to open the current project's remote repository in browser", bundle: .module),
        order: 90
    )

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        let projectPath = context.lumiCore?.projectState?.currentProject?.path ?? ""
        return [
            LumiStatusBarItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName,
                placement: .leading,
                statusBarView: {
                    OpenRemoteStatusBarView(projectPath: projectPath)
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

// MARK: - Status Bar View

/// 远程仓库状态栏视图
public struct OpenRemoteStatusBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    private let projectPath: String
    @State private var remoteURL: URL?
    @State private var isLoading = false

    public init(projectPath: String) {
        self.projectPath = projectPath
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
        .onChange(of: projectPath) { _, _ in
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
        guard !projectPath.isEmpty else {
            remoteURL = nil
            return
        }

        isLoading = true

        Task {
            let url = await fetchRemoteURL(for: projectPath)

            await MainActor.run {
                self.remoteURL = url
                self.isLoading = false
            }
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
        let result = try? await Shell.execute(
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
    @LumiUI.LumiTheme private var theme: any LumiUITheme

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
