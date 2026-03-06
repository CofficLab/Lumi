import SwiftUI
import MagicKit

/// 项目文件树视图
struct ProjectTreeView: View {
    @EnvironmentObject var agentProvider: AgentProvider
    @State private var projectRoot: URL?
    @State private var rootItems: [FileTreeNode] = []
    @State private var isLoading = false
    @State private var currentProjectPath: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerSection

            Divider()
                .background(Color.white.opacity(0.1))

            // 文件树内容
            if isLoading {
                ProjectTreeLoadingView()
            } else if rootItems.isEmpty {
                ProjectTreeEmptyView()
            } else {
                fileTreeView
            }
        }
        .padding(.vertical, 8)
        .background(DesignTokens.Material.glassThick)
        .onChange(of: agentProvider.currentProjectPath) { _, newPath in
            if !newPath.isEmpty && newPath != currentProjectPath {
                currentProjectPath = newPath
                loadProjectTree(path: newPath)
            }
        }
        .onAppear {
            if !agentProvider.currentProjectPath.isEmpty {
                currentProjectPath = agentProvider.currentProjectPath
                loadProjectTree(path: agentProvider.currentProjectPath)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        ProjectTreeHeader(
            projectRoot: projectRoot,
            onRefresh: refresh
        )
    }

    // MARK: - File Tree View

    private var fileTreeView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(rootItems) { item in
                    FileTreeNodeView(
                        node: item,
                        depth: 0,
                        projectPath: currentProjectPath,
                        onFileDrop: handleFileDrop,
                        onFileSelect: handleFileSelect
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Actions

    private func refresh() {
        if !agentProvider.currentProjectPath.isEmpty {
            loadProjectTree(path: agentProvider.currentProjectPath)
        }
    }

    /// 处理文件拖放 - 将文件路径传递给 AgentProvider
    private func handleFileDrop(url: URL) {
        // 通过 NotificationCenter 发送通知，让 InputAreaView 接收
        NotificationCenter.postFileDroppedToChat(fileURL: url)
    }

    /// 处理文件选择 - 更新 AgentProvider 的选中文件
    private func handleFileSelect(url: URL) {
        agentProvider.selectFile(at: url)
    }

    private func loadProjectTree(path: String) {
        isLoading = true
        projectRoot = URL(fileURLWithPath: path)

        Task {
            let items = await loadDirectoryContents(url: projectRoot!, depth: 0, maxDepth: 3, projectPath: path)
            await MainActor.run {
                rootItems = items
                isLoading = false
            }
        }
    }

    private func loadDirectoryContents(url: URL, depth: Int, maxDepth: Int, projectPath: String) async -> [FileTreeNode] {
        guard depth < maxDepth else { return [] }

        var items: [FileTreeNode] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            for fileURL in contents {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                    let isDirectory = resourceValues.isDirectory ?? false
                    
                    // 检查该目录是否之前被展开过
                    let wasExpanded = FileTreeStateManager.shared.isExpanded(url: fileURL, projectPath: projectPath)

                    let node = FileTreeNode(
                        name: fileURL.lastPathComponent,
                        url: fileURL,
                        isDirectory: isDirectory,
                        isExpanded: wasExpanded,
                        children: isDirectory ? [] : nil
                    )
                    items.append(node)
                } catch {
                    continue
                }
            }
        } catch {
            return []
        }

        // 按类型和名称排序：文件夹在前，文件在后
        items.sort { left, right in
            if left.isDirectory == right.isDirectory {
                return left.name.localizedStandardCompare(right.name) == .orderedAscending
            }
            return left.isDirectory
        }

        return items
    }
}

#Preview {
    ProjectTreeView()
        .frame(width: 220, height: 400)
        .inRootView()
}
