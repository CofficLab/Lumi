import SwiftUI
import MagicKit

/// 项目文件树节点视图
struct FileTreeNodeView: View {
    let node: FileTreeNode
    let depth: Int
    let projectPath: String
    let onFileDrop: (URL) -> Void
    let onFileSelect: (URL) -> Void
    @EnvironmentObject var agentProvider: AgentProvider
    @EnvironmentObject var projectViewModel: ProjectViewModel

    @State private var isExpanded = false
    @State private var children: [FileTreeNode] = []
    @State private var isLoading = false
    @State private var hasLoadedOnce = false

    /// 每层缩进量 (参考 VS Code 的默认缩进)
    private let indentPerLevel: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 节点行
            nodeRow
            // 子节点
            if isExpanded && node.isDirectory {
                if isLoading {
                    loadingIndicator
                } else if !children.isEmpty {
                    childNodes
                }
            }
        }
        .onAppear {
            // 首次出现时，从状态管理器恢复展开状态
            if !hasLoadedOnce {
                hasLoadedOnce = true
                let savedState = FileTreeStateManager.shared.isExpanded(url: node.url, projectPath: projectPath)
                if savedState {
                    isExpanded = true
                    // 如果之前是展开的，自动加载子节点
                    if children.isEmpty && !isLoading {
                        loadChildren()
                    }
                }
            }
        }
    }

    // MARK: - Node Row

    private var nodeRow: some View {
        HStack(spacing: 6) {
            // 展开/折叠箭头
            if node.isDirectory {
                expandCollapseButton
            } else {
                Spacer().frame(width: 12)
            }

            // 图标
            nodeIcon

            // 名称
            nodeName

            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
        // 添加拖拽支持
        .draggable(node.url) {
            DragPreview(fileURL: node.url)
        }
    }

    private var expandCollapseButton: some View {
        Button(action: toggle) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 8))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
        }
        .buttonStyle(.plain)
        .frame(width: 12)
    }

    private var nodeIcon: some View {
        Image(systemName: node.icon)
            .font(.system(size: 10))
            .foregroundColor(node.isDirectory ? .accentColor : DesignTokens.Color.semantic.textSecondary)
            .frame(width: 14)
    }

    private var nodeName: some View {
        Text(node.name)
            .font(.system(size: 10))
            .foregroundColor(isSelected ? .accentColor : DesignTokens.Color.semantic.textPrimary)
            .lineLimit(1)
    }

    // MARK: - Loading Indicator

    private var loadingIndicator: some View {
        HStack(spacing: 0) {
            ProgressView()
                .frame(width: 8, height: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, indentPerLevel)
        .padding(.vertical, 4)
    }

    // MARK: - Child Nodes

    private var childNodes: some View {
        Group {
            ForEach(children) { child in
                FileTreeNodeView(
                    node: child,
                    depth: depth + 1,
                    projectPath: projectPath,
                    onFileDrop: onFileDrop,
                    onFileSelect: onFileSelect
                )
            }
        }
        .padding(.leading, indentPerLevel)
    }

    // MARK: - Properties

    /// 检查当前节点是否被选中
    private var isSelected: Bool {
        projectViewModel.selectedFileURL == node.url
    }

    // MARK: - Actions

    private func handleTap() {
        if node.isDirectory {
            toggle()
        } else {
            // 选择文件
            onFileSelect(node.url)
        }
    }

    private func toggle() {
        isExpanded.toggle()
        
        // 保存状态到持久化存储
        FileTreeStateManager.shared.setExpanded(isExpanded, url: node.url, projectPath: projectPath)

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
