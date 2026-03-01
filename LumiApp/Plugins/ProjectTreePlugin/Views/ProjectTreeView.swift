import SwiftUI
import OSLog
import MagicKit

/// 项目文件树视图
struct ProjectTreeView: View {
    @EnvironmentObject var agentProvider: AgentProvider
    @State private var projectRoot: URL?
    @State private var rootItems: [FileTreeNode] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerSection

            Divider()
                .background(Color.white.opacity(0.1))

            // 文件树内容
            if isLoading {
                loadingView
            } else if rootItems.isEmpty {
                emptyView
            } else {
                fileTreeView
            }
        }
        .padding(.vertical, 8)
        .background(DesignTokens.Material.glassThick)
        .onChange(of: agentProvider.currentProjectPath) { _, newPath in
            if !newPath.isEmpty {
                loadProjectTree(path: newPath)
            }
        }
        .onAppear {
            if !agentProvider.currentProjectPath.isEmpty {
                loadProjectTree(path: agentProvider.currentProjectPath)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Image(systemName: "folder.fill")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)

            Text("项目文件")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Spacer()

            // 刷新按钮
            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - File Tree View

    private var fileTreeView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(rootItems) { item in
                    FileTreeNodeView(node: item, depth: 0)
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.7)
            Text("加载中...")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 24))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

            Text("暂无文件")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func refresh() {
        if !agentProvider.currentProjectPath.isEmpty {
            loadProjectTree(path: agentProvider.currentProjectPath)
        }
    }

    private func loadProjectTree(path: String) {
        isLoading = true
        projectRoot = URL(fileURLWithPath: path)

        Task {
            let items = await loadDirectoryContents(url: projectRoot!, depth: 0, maxDepth: 3)
            await MainActor.run {
                rootItems = items
                isLoading = false
            }
        }
    }

    private func loadDirectoryContents(url: URL, depth: Int, maxDepth: Int) async -> [FileTreeNode] {
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

                    let node = FileTreeNode(
                        name: fileURL.lastPathComponent,
                        url: fileURL,
                        isDirectory: isDirectory,
                        isExpanded: false,
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

// MARK: - File Tree Node

struct FileTreeNode: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
    var isExpanded: Bool
    var children: [FileTreeNode]?
}

// MARK: - File Tree Node View

struct FileTreeNodeView: View {
    let node: FileTreeNode
    let depth: Int
    @State private var isExpanded = false
    @State private var children: [FileTreeNode] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 节点行
            HStack(spacing: 6) {
                // 展开/折叠箭头
                if node.isDirectory {
                    Button(action: toggle) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8))
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }

                // 图标
                Image(systemName: node.icon)
                    .font(.system(size: 10))
                    .foregroundColor(node.isDirectory ? .accentColor : DesignTokens.Color.semantic.textSecondary)
                    .frame(width: 14)

                // 名称
                Text(node.name)
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .onTapGesture {
                if node.isDirectory {
                    toggle()
                }
            }

            // 子节点
            if isExpanded && node.isDirectory {
                if isLoading {
                    HStack {
                        Spacer().frame(width: 20)
                        ProgressView()
                            .scaleEffect(0.5)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } else if !children.isEmpty {
                    ForEach(children) { child in
                        FileTreeNodeView(node: child, depth: depth + 1)
                    }
                }
            }
        }
    }

    private func toggle() {
        isExpanded.toggle()

        if isExpanded && children.isEmpty && !isLoading {
            loadChildren()
        }
    }

    private func loadChildren() {
        isLoading = true

        Task {
            let loadedChildren = await loadChildrenAsync()
            await MainActor.run {
                children = loadedChildren
                isLoading = false
            }
        }
    }

    private func loadChildrenAsync() async -> [FileTreeNode] {
        var items: [FileTreeNode] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: node.url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            for fileURL in contents {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                    let isDirectory = resourceValues.isDirectory ?? false

                    let childNode = FileTreeNode(
                        name: fileURL.lastPathComponent,
                        url: fileURL,
                        isDirectory: isDirectory,
                        isExpanded: false,
                        children: isDirectory ? [] : nil
                    )
                    items.append(childNode)
                } catch {
                    continue
                }
            }
        } catch {
            return []
        }

        items.sort { left, right in
            if left.isDirectory == right.isDirectory {
                return left.name.localizedStandardCompare(right.name) == .orderedAscending
            }
            return left.isDirectory
        }

        return items
    }
}

// MARK: - FileTreeNode Extension

extension FileTreeNode {
    var icon: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        } else {
            return fileIcon
        }
    }

    private var fileIcon: String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "m", "mm": return "m"
        case "h": return "h.square"
        case "xcodeproj", "xcworkspace": return "xmark.shield"
        case "plist": return "doc.plaintext"
        case "json": return "doc.plaintext"
        case "xml": return "doc.plaintext"
        case "md": return "doc.text"
        case "txt": return "doc.text"
        case "rtf": return "doc.richtext"
        case "pdf": return "doc.fill"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        case "zip", "tar", "gz", "rar": return "doc.zipper"
        default: return "doc"
        }
    }
}

#Preview {
    ProjectTreeView()
        .frame(width: 220, height: 400)
        .environmentObject(AgentProvider.shared)
        .inRootView()
}
