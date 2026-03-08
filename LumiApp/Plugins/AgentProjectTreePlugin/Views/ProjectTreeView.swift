import SwiftUI
import MagicKit
import OSLog

/// 项目文件树视图
struct ProjectTreeView: View, SuperLog {
    nonisolated static let emoji = "🌲"
    nonisolated static let verbose = true

    @EnvironmentObject var projectViewModel: ProjectViewModel
    @State private var projectRoot: URL?
    @State private var rootItems: [FileTreeNode] = []
    @State private var isLoading = false
    @State private var currentProjectPath: String = ""
    
    // 用于追踪 body 计算次数
    @State private var bodyComputeCount = 0

    var body: some View {
        let _ = Self.logBodyCompute()
        
        return VStack(spacing: 0) {
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
        .background(.background.opacity(0.8))
        .onChange(of: projectViewModel.currentProjectPath) { _, newPath in
            if Self.verbose {
                os_log("\(Self.t)🔄 onChange 触发 - 项目路径变化: \(newPath)")
            }
            if !newPath.isEmpty && newPath != currentProjectPath {
                currentProjectPath = newPath
                loadProjectTree(path: newPath)
            } else {
                if Self.verbose {
                    os_log("\(Self.t)⏭️ onChange 跳过 - 路径为空或相同")
                }
            }
        }
        .onAppear {
            if Self.verbose {
                os_log("\(Self.t)👁️ ProjectTreeView onAppear")
            }
            let projectPath = projectViewModel.currentProjectPath
            if !projectPath.isEmpty {
                currentProjectPath = projectPath
                loadProjectTree(path: projectPath)
            } else {
                if Self.verbose {
                    os_log("\(Self.t)⚠️ 当前项目路径为空")
                }
            }
        }
    }
    
    private static func logBodyCompute() {
        if verbose {
            os_log("\(Self.t)🔁 body 计算")
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
                        isSelected: projectViewModel.selectedFileURL == item.url,
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
        if Self.verbose {
            os_log("\(Self.t)🔄 手动刷新项目树")
        }
        let projectPath = projectViewModel.currentProjectPath
        if !projectPath.isEmpty {
            loadProjectTree(path: projectPath)
        } else {
            if Self.verbose {
                os_log("\(Self.t)⚠️ 刷新失败：项目路径为空")
            }
        }
    }

    /// 处理文件拖放 - 将文件路径传递给 AgentProvider
    private func handleFileDrop(url: URL) {
        if Self.verbose {
            os_log("\(Self.t)📎 文件拖放: \(url.lastPathComponent)")
        }
        // 通过 NotificationCenter 发送通知，让 InputAreaView 接收
        NotificationCenter.postFileDroppedToChat(fileURL: url)
    }

    /// 处理文件选择 - 更新 ProjectViewModel 的选中文件
    private func handleFileSelect(url: URL) {
        if Self.verbose {
            os_log("\(Self.t)👆 选择文件: \(url.lastPathComponent)")
        }
        projectViewModel.selectFile(at: url)
    }

    private func loadProjectTree(path: String) {
        if Self.verbose {
            os_log("\(Self.t)📂 开始加载项目树: \(path)")
        }
        isLoading = true
        projectRoot = URL(fileURLWithPath: path)

        Task {
            let startTime = Date()
            let items = await loadDirectoryContents(url: projectRoot!, depth: 0, maxDepth: 3, projectPath: path)
            let duration = Date().timeIntervalSince(startTime)

            await MainActor.run {
                rootItems = items
                isLoading = false
                if Self.verbose {
                    os_log("\(Self.t)✅ 项目树加载完成: \(items.count) 个根项, 耗时 \(String(format: "%.2f", duration))s")
                }
            }
        }
    }

    private func loadDirectoryContents(url: URL, depth: Int, maxDepth: Int, projectPath: String) async -> [FileTreeNode] {
        guard depth < maxDepth else {
            if Self.verbose {
                os_log("\(Self.t)⏹️ 达到最大深度限制: depth=\(depth)")
            }
            return []
        }

        var items: [FileTreeNode] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            if Self.verbose && depth == 0 {
                os_log("\(Self.t)📂 目录内容: \(url.lastPathComponent) 包含 \(contents.count) 个项")
            }

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
                    if Self.verbose {
                        os_log("\(Self.t)⚠️ 读取文件信息失败: \(fileURL.lastPathComponent), error: \(error.localizedDescription)")
                    }
                    continue
                }
            }
        } catch {
            if Self.verbose {
                os_log("\(Self.t)❌ 读取目录失败: \(url.lastPathComponent), error: \(error.localizedDescription)")
            }
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
