import Foundation
import LumiKernel
import SwiftUI

/// 简单文件树视图
///
/// 从 kernel 获取当前项目路径，展示文件树。
struct SimpleFileTreeView: View {
    @ObservedObject var kernel: LumiKernel
    @State private var rootNode: FileNode?
    @State private var expandedPaths: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            if let node = rootNode {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        FileTreeNodeView(node: node, depth: 0, expandedPaths: $expandedPaths)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Project Open")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            loadProjectPath()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .currentProjectDidChange)
        ) { _ in
            loadProjectPath()
        }
    }

    private func loadProjectPath() {
        let projectPath = kernel.project?.currentProject?.path
        guard let path = projectPath, !path.isEmpty else {
            rootNode = nil
            return
        }

        let url = URL(fileURLWithPath: path)
        rootNode = FileNode(url: url, name: url.lastPathComponent, isDirectory: true)
    }
}

/// 文件树节点数据模型
struct FileNode: Identifiable {
    let id: String
    let url: URL
    let name: String
    let isDirectory: Bool
    var children: [FileNode] = []

    init(url: URL, name: String, isDirectory: Bool) {
        self.id = url.path
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
    }

    mutating func loadChildren() {
        guard isDirectory else { return }
        guard children.isEmpty else { return }

        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        children = contents
            .map { item in
                let name = item.lastPathComponent
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                return FileNode(url: item, name: name, isDirectory: isDir)
            }
            .sorted { a, b in
                if a.isDirectory != b.isDirectory {
                    return a.isDirectory
                }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
    }
}

/// 文件树节点视图
struct FileTreeNodeView: View {
    let node: FileNode
    let depth: Int
    @Binding var expandedPaths: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
                    .frame(width: 16, height: 16)

                Text(node.name)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.leading, CGFloat(depth * 16 + 8))
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .onTapGesture {
                toggleExpansion()
            }

            if isExpanded && node.isDirectory {
                ForEach(childrenForDisplay) { child in
                    FileTreeNodeView(node: child, depth: depth + 1, expandedPaths: $expandedPaths)
                }
            }
        }
    }

    private var isExpanded: Bool {
        expandedPaths.contains(node.id)
    }

    private var childrenForDisplay: [FileNode] {
        var mutableNode = node
        mutableNode.loadChildren()
        return mutableNode.children
    }

    private func toggleExpansion() {
        guard node.isDirectory else { return }
        if expandedPaths.contains(node.id) {
            expandedPaths.remove(node.id)
        } else {
            expandedPaths.insert(node.id)
        }
    }

    private var iconName: String {
        if node.isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }
        return iconForFile(node.name)
    }

    private var iconColor: Color {
        if node.isDirectory {
            return .blue
        }
        return .secondary
    }

    private func iconForFile(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "h", "m", "mm": return "c"
        case "c", "cpp", "cc", "cxx": return "c"
        case "js", "ts", "jsx", "tsx": return "js"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "md", "markdown": return "markdown"
        case "txt": return "doc"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        case "pdf": return "doc.richtext"
        default: return "doc"
        }
    }
}
