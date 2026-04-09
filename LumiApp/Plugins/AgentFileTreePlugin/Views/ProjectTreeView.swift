import SwiftUI
import MagicKit
import os

/// 项目文件树视图 - 使用 List 优化性能，支持文件系统变化自动刷新
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
    nonisolated private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree")

    var body: some View {
        VStack(spacing: 0) {
            // 文件树内容
            contentView
        }
        .frame(maxHeight: .infinity)
        .onChange(of: projectVM.currentProjectPath) { _, newPath in
            setupWatcher(for: newPath)
            loadProject(at: newPath)
        }
        .onAppear {
            setupWatcher(for: projectVM.currentProjectPath)
            loadProject(at: projectVM.currentProjectPath)
        }
        .onDisappear {
            watcher?.stopAll()
            watcher = nil
        }
    }
}

// MARK: - View

extension ProjectTreeView {
    @ViewBuilder
    private var contentView: some View {
        if isLoading && rootURLs.isEmpty {
            loadingView
        } else if rootURLs.isEmpty {
            emptyView
        } else {
            fileList
        }
    }

    private var fileList: some View {
        List {
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
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
            }
        }
        .environment(\.defaultMinListRowHeight, 0)
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .listRowBackground(Color.clear)
        .padding(.horizontal, -8)
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

// MARK: - Watcher

extension ProjectTreeView {
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
                    options: [.skipsHiddenFiles]
                )

                // 排序：文件夹在前
                let sorted = contents.sorted { a, b in
                    let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if aIsDir == bIsDir {
                        return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
                    }
                    return aIsDir
                }

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
}

// MARK: - Preview

#Preview {
    ProjectTreeView()
        .inRootView()
        .frame(width: 250, height: 400)
}
