import AppKit
import Foundation
import LumiKernel
import LumiUI
import ShellKit
import SwiftUI

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