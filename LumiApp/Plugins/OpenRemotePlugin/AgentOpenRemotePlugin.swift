import LumiUI
import MagicKit
import SwiftUI
import Foundation
import os
import ShellKit

/// 在浏览器中打开远程仓库插件
///
/// 在 Agent 模式的状态栏添加一个图标，点击后在浏览器中打开当前项目的远程仓库地址。
actor AgentOpenRemotePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🌐"

    nonisolated static let verbose: Bool = false

    static let id: String = "AgentOpenRemote"
    static let displayName: String = String(localized: "Open Remote Repository", table: "AgentOpenRemote")
    static let description: String = String(localized: "Displays a button in the header to open the current project's remote repository in browser", table: "AgentOpenRemote")
    static let iconName: String = "safari"
    static let isConfigurable: Bool = true
    static let enable: Bool = true
    static var order: Int { 90 }

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = AgentOpenRemotePlugin()

    // MARK: - Status Bar

    /// 添加状态栏左侧视图
    @MainActor
    func addStatusBarLeadingView(activeIcon: String?) -> AnyView? {
        return AnyView(OpenRemoteStatusBarView())
    }
}

// MARK: - Status Bar View

/// 远程仓库状态栏视图
struct OpenRemoteStatusBarView: View {
    @EnvironmentObject private var projectVM: WindowProjectVM
    @State private var remoteURL: URL?
    @State private var isLoading = false

    var body: some View {
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
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            updateRemoteURL()
        }
        .onApplicationDidBecomeActive {
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

                Text(String(localized: "加载中...", table: "OpenRemotePlugin"))
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(String(localized: "在浏览器中打开远程仓库", table: "AgentOpenRemote"))
        }
    }

    /// 无远程仓库的视图
    private var noRemoteView: some View {
        HStack(spacing: 6) {
            Image(systemName: "safari")
                .font(.system(size: 10))

            Text(String(localized: "无远程仓库", table: "OpenRemotePlugin"))
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(.secondary.opacity(0.5))
        .help(String(localized: "无远程仓库", table: "AgentOpenRemote"))
    }

    private func updateRemoteURL() {
        guard !projectVM.currentProjectPath.isEmpty else {
            remoteURL = nil
            return
        }

        isLoading = true

        Task {
            let projectPath = projectVM.currentProjectPath
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
struct OpenRemoteDetailView: View {
    let url: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "safari")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "7C6FFF"))

                Text(String(localized: "远程仓库", table: "OpenRemotePlugin"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Spacer()

                if let url = url {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text(String(localized: "打开", table: "OpenRemotePlugin"))
                        }
                        .font(.system(size: 12))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Divider()

            if let url = url {
                // URL 显示
                HStack(spacing: 8) {
                    Text(String(localized: "URL", table: "OpenRemotePlugin"))
                        .font(.system(size: 12))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        .frame(width: 60, alignment: .leading)

                    Text(url.absoluteString)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                        .lineLimit(2)
                        .textSelection(.enabled)

                    Spacer()

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "复制 URL", table: "OpenRemotePlugin"))
                }
            } else {
                // 无远程仓库
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "FF9F0A"))

                        Text(String(localized: "当前项目没有远程仓库", table: "OpenRemotePlugin"))
                            .font(.system(size: 13))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
