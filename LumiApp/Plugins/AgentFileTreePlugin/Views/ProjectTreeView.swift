import MagicKit
import os
import SwiftUI

/// 项目文件树视图
struct ProjectTreeView: View {
    @EnvironmentObject var projectVM: ProjectVM

    /// 当前项目根目录下的一级文件 / 文件夹
    @State private var rootURLs: [URL] = []

    /// 是否正在加载项目结构
    @State private var isLoading = false

    /// 文件系统变化监听器
    @State private var watcher: ProjectTreeWatcher?

    /// 当前正在监控的已展开目录集合
    @State private var expandedDirectoryURLs: Set<URL> = []

    /// 全局刷新令牌，每次文件系统变化时递增，触发所有展开节点重新加载
    @State private var refreshToken: Int = 0

    /// Logger
    private nonisolated static let logger = ProjectTreePlugin.logger

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && rootURLs.isEmpty {
                loadingView
            } else if rootURLs.isEmpty {
                emptyView
            } else {
                fileList
            }
        }
        .frame(maxHeight: .infinity)
        .onChange(of: projectVM.currentProjectPath, onProjectPathChanged)
        .onChange(of: projectVM.selectedFileURL, onSelectedFileChanged)
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .onSyncSelectedFile(perform: onSyncSelectedFile)
    }
}

// MARK: - View

extension ProjectTreeView {
    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(rootURLs, id: \.self) { url in
                    FileNodeView(
                        url: url,
                        depth: 0,
                        selectedURL: projectVM.selectedFileURL,
                        onSelect: { selectedURL in
                            projectVM.selectFile(at: selectedURL)
                        },
                        onDirectoryExpanded: { dirURL in
                            handleDirectoryExpanded(dirURL)
                        },
                        onDirectoryCollapsed: { dirURL in
                            handleDirectoryCollapsed(dirURL)
                        },
                        refreshToken: refreshToken
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text(String(localized: "Loading...", table: "ProjectTree"))
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text(String(localized: "No project", table: "ProjectTree"))
                .font(.system(size: 11))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Event Handler

extension ProjectTreeView {
    private func onSyncSelectedFile(path: String) {
        let url = URL(fileURLWithPath: path)
        projectVM.selectFile(at: url)
    }

    private func onProjectPathChanged() {
        setupWatcher(for: self.projectVM.currentProjectPath)
        loadProject(at: self.projectVM.currentProjectPath)
    }

    private func onAppear() {
        setupWatcher(for: projectVM.currentProjectPath)
        loadProject(at: projectVM.currentProjectPath)
    }

    private func onDisappear() {
        watcher?.stopAll()
        watcher = nil
    }

    private func onSelectedFileChanged() {
        if let url = projectVM.selectedFileURL {
            expandToFile(url)
        }
    }

    /// 设置文件系统监听器
    private func setupWatcher(for path: String) {
        // 先停止旧的监听
        watcher?.stopAll()
        expandedDirectoryURLs.removeAll()

        guard !path.isEmpty else {
            watcher = nil
            return
        }

        let rootURL = URL(fileURLWithPath: path)

        // 创建新的监听器
        watcher = ProjectTreeWatcher { changedURL in
            Self.logger.info("🔄 文件系统变化检测: \(changedURL.lastPathComponent)")
            Task { @MainActor in
                handleFileSystemChange(changedURL: changedURL, rootURL: rootURL)
            }
        }

        // 开始监听根目录
        watcher?.startWatching(url: rootURL)
    }

    /// 目录展开时注册监听
    private func handleDirectoryExpanded(_ dirURL: URL) {
        expandedDirectoryURLs.insert(dirURL)
        watcher?.startWatching(url: dirURL)
    }

    /// 目录折叠时取消监听
    private func handleDirectoryCollapsed(_ dirURL: URL) {
        expandedDirectoryURLs.remove(dirURL)
        watcher?.stopWatching(url: dirURL)
    }

    /// 处理文件系统变化
    private func handleFileSystemChange(changedURL: URL, rootURL: URL) {
        let standardizedChanged = changedURL.standardizedFileURL
        let standardizedRoot = rootURL.standardizedFileURL

        if standardizedChanged.path == standardizedRoot.path {
            // 根目录变化 → 重新加载整个根列表
            loadProject(at: rootURL.path)
        }

        // 无论是否根目录变化，都递增刷新令牌，触发所有已展开目录重新加载子节点
        refreshToken += 1
    }
}

// MARK: - Action

extension ProjectTreeView {
    private func loadProject(at path: String) {
        guard !path.isEmpty else {
            rootURLs = []
            return
        }

        let url = URL(fileURLWithPath: path)
        isLoading = true

        Task.detached(priority: .userInitiated) {
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: []
                )

                // 使用 Service 进行过滤和排序
                let sorted = ProjectTreeFileService.filterAndSortContents(contents)

                await MainActor.run {
                    self.rootURLs = sorted
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.rootURLs = []
                    self.isLoading = false
                }
            }
        }
    }

    /// 自动展开到指定文件所在的目录
    private func expandToFile(_ fileURL: URL) {
        // 获取当前项目的根路径
        let rootPath = projectVM.currentProjectPath
        guard !rootPath.isEmpty else { return }

        let rootURL = URL(fileURLWithPath: rootPath)

        // 确保文件在项目目录下
        guard fileURL.path.hasPrefix(rootPath) else { return }

        // 获取文件相对于根目录的路径组件
        let relativePath = fileURL.path.replacingOccurrences(of: rootPath + "/", with: "")
        let components = relativePath.split(separator: "/").map(String.init)

        // 逐级展开目录
        var currentURL = rootURL
        let directoriesToExpand = components.dropLast()

        for dirName in directoriesToExpand {
            currentURL = currentURL.appendingPathComponent(dirName)
            expandedDirectoryURLs.insert(currentURL)
            watcher?.startWatching(url: currentURL)
        }

        // 刷新令牌以触发子节点重新加载
        if !components.isEmpty {
            refreshToken += 1
        }
    }
}

// MARK: - Preview

#Preview {
    ProjectTreeView()
        .inRootView()
        .frame(width: 250, height: 400)
}
