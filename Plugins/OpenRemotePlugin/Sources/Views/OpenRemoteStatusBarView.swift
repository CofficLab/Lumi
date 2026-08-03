import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// 远程仓库状态栏视图
///
/// 本视图仅负责：
/// 1. 监听当前项目路径变化；
/// 2. 委托 `RemoteRepositoryService` 解析远程 URL；
/// 3. 委托 `URLOpeningService` 打开 URL。
///
/// 具体的 Git 探测 / shell 调用 / URL 格式化均在服务层完成。
public struct OpenRemoteStatusBarView: View, SuperLog {
    nonisolated public static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.open-remote.status"
    )
    nonisolated public static let emoji = "🌐"
    nonisolated public static let verbose = false

    @LumiTheme private var theme: any LumiUITheme
    @StateObject private var observer: ProjectPathObserver

    @State private var remoteURL: URL?
    @State private var isLoading = false
    @State private var lastResolvedPath: String = ""

    public init(project: any ProjectProviding) {
        Self.logger.info("\(Self.i)statusBarView init, project=\(project.currentProject?.path ?? "nil")")
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
                URLOpeningService.shared.openInBrowser(url)
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

    /// 调度一次远程 URL 解析
    ///
    /// 由 `onAppear` / `onChange` / `didBecomeActiveNotification` 触发；
    /// 同一路径连续触发会被去重，避免重复调 shell。
    private func updateRemoteURL() {
        let path = currentProjectPath
        guard path != lastResolvedPath else {
            if Self.verbose {
                Self.logger.info("\(Self.t)updateRemoteURL 跳过: 路径未变 \(path, privacy: .public)")
            }
            return
        }
        lastResolvedPath = path

        guard !path.isEmpty else {
            if Self.verbose {
                Self.logger.info("\(Self.t)updateRemoteURL: 路径为空，清除远程地址")
            }
            remoteURL = nil
            isLoading = false
            return
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)updateRemoteURL 开始解析, path=\(path, privacy: .public)")
        }
        isLoading = true

        Task {
            let url = await RemoteRepositoryService.shared.resolveRemoteURL(for: path)

            guard lastResolvedPath == path else {
                if Self.verbose {
                    Self.logger.info("\(Self.t)updateRemoteURL 丢弃过期结果, 当前路径=\(self.lastResolvedPath, privacy: .public), 解析路径=\(path, privacy: .public)")
                }
                return
            }

            remoteURL = url
            isLoading = false
            if Self.verbose {
                if let url {
                    Self.logger.info("\(Self.t)updateRemoteURL 完成, remote=\(url.absoluteString, privacy: .public)")
                } else {
                    Self.logger.info("\(Self.t)updateRemoteURL 完成, remote=nil\(self.r("无远程仓库或非 git 仓库"))")
                }
            }
        }
    }
}
