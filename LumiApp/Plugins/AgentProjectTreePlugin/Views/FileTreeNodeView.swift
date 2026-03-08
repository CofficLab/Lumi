import SwiftUI
import MagicKit
import OSLog

/// 文件树节点视图
struct FileTreeNodeView: View {
    let node: FileTreeNode
    let depth: Int
    @ObservedObject var viewModel: FileTreeViewModel
    
    /// 每层缩进量
    private let indentPerLevel: CGFloat = 16
    
    /// 是否展开
    private var isExpanded: Bool {
        viewModel.isExpanded(node.url)
    }
    
    /// 是否选中
    private var isSelected: Bool {
        viewModel.selectedFileURL == node.url
    }
    
    /// 是否正在加载
    private var isLoading: Bool {
        viewModel.isLoading(node.url)
    }
    
    /// 子节点
    private var children: [FileTreeNode] {
        viewModel.children(for: node.url)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 节点行
            nodeRow
            
            // 子节点（如果展开）
            if isExpanded && node.isDirectory {
                childNodesView
            }
        }
    }
    
    // MARK: - Node Row
    
    private var nodeRow: some View {
        HStack(spacing: 6) {
            // 展开/折叠箭头（仅文件夹）
            if node.isDirectory {
                expandCollapseButton
            } else {
                Spacer().frame(width: 12)
            }
            
            // 图标
            Image(systemName: node.icon(isExpanded: isExpanded))
                .font(.system(size: 10))
                .foregroundColor(node.isDirectory ? .accentColor : .secondary)
                .frame(width: 14)
            
            // 名称
            Text(node.name)
                .font(.system(size: 10))
                .foregroundColor(isSelected ? .accentColor : .primary)
                .lineLimit(1)
            
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
    }
    
    private var expandCollapseButton: some View {
        Button(action: {
            viewModel.toggleExpansion(for: node.url)
        }) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .frame(width: 12)
    }
    
    // MARK: - Child Nodes
    
    @ViewBuilder
    private var childNodesView: some View {
        if isLoading {
            ProgressView()
                .frame(width: 8, height: 8)
                .padding(.leading, CGFloat(depth + 1) * indentPerLevel + 6)
                .padding(.vertical, 4)
        } else if !children.isEmpty {
            ForEach(children) { child in
                FileTreeNodeView(
                    node: child,
                    depth: depth + 1,
                    viewModel: viewModel
                )
            }
            .padding(.leading, indentPerLevel)
        }
    }
    
    // MARK: - Actions
    
    private func handleTap() {
        if node.isDirectory {
            viewModel.toggleExpansion(for: node.url)
        } else {
            viewModel.selectFile(node.url)
        }
    }
}

#Preview {
    let viewModel = FileTreeViewModel()
    viewModel.rootNodes = [
        FileTreeNode(
            name: "LumiApp",
            url: URL(fileURLWithPath: "/test/LumiApp"),
            isDirectory: true,
            isExpanded: false,
            children: nil
        )
    ]
    
    return FileTreeNodeView(
        node: viewModel.rootNodes[0],
        depth: 0,
        viewModel: viewModel
    )
    .frame(width: 250)
}
