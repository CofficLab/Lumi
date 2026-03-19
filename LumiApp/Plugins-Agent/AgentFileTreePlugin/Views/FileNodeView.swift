import SwiftUI
import MagicKit

/// 文件树节点视图 - 自定义递归布局
struct FileNodeView: View, SuperLog {
    /// 项目状态 ViewModel，用于处理文件/目录操作
    @EnvironmentObject private var ProjectVM: ProjectVM
    /// 日志前缀的表情符号（文件树节点）
    nonisolated static let emoji = "📁"
    
    /// 是否输出详细日志
    nonisolated static let verbose = false
    
    let url: URL
    let depth: Int
    
    /// 当前选中的文件 URL，用于高亮选中行
    let selectedURL: URL?
    
    /// 选中某个文件节点的回调
    let onSelect: (URL) -> Void
    
    /// 本地展开状态
    @State private var isExpanded: Bool = false
    
    /// 本地子节点缓存
    @State private var children: [URL] = []
    
    /// 是否处于 hover 状态（用于高亮当前行）
    @State private var isHovering: Bool = false
    
    /// 唯一ID用于追踪
    private let nodeId = UUID()
    
    /// 是否文件夹
    private var isDirectory: Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
    
    /// 文件名（不含路径）
    private var fileName: String {
        url.lastPathComponent
    }
    
    var body: some View {
        let isSelected = selectedURL == url
        
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                // 展开箭头（仅目录）
                if isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 10)
                } else {
                    // 与目录图标对齐
                    Color.clear
                        .frame(width: 10)
                }
                
                // 图标
                Image(systemName: iconName)
                    .font(.system(size: 10))
                    .foregroundColor(isDirectory ? .accentColor : .secondary)
                    .frame(width: 14)
                
                // 名称
                Text(fileName)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? Color.white : .primary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .padding(.leading, CGFloat(depth) * 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                rowBackground(isSelected: isSelected)
            )
            .contentShape(Rectangle())
            .contextMenu {
                Button {
                    ProjectVM.openInFinder(url)
                } label: {
                    Label("在 Finder 中显示", systemImage: "finder")
                }
                
                Button {
                    ProjectVM.openInVSCode(url)
                } label: {
                    Label("在 VS Code 中打开", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                
                Button {
                    ProjectVM.openInTerminal(url)
                } label: {
                    Label("在终端中打开", systemImage: "terminal")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    ProjectVM.deleteItem(at: url)
                } label: {
                    Label("移到废纸篓", systemImage: "trash")
                }
            }
            .onTapGesture {
                if isDirectory {
                    isExpanded.toggle()
                    if isExpanded && children.isEmpty {
                        loadChildren()
                    }
                }
                onSelect(url)
            }
            .onHover { hovering in
                isHovering = hovering
            }
            
            if isDirectory && isExpanded && !children.isEmpty {
                VStack(spacing: 0) {
                    ForEach(children, id: \.self) { childURL in
                        FileNodeView(
                            url: childURL,
                            depth: depth + 1,
                            selectedURL: selectedURL,
                            onSelect: onSelect
                        )
                    }
                }
            }
        }
    }
}

// MARK: - View

extension FileNodeView {
    /// 当前节点对应的系统图标名称
    private var iconName: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }
        return iconForFile(url)
    }
    
    /// 根据文件扩展名返回对应的系统图标名称
    /// - Parameter url: 文件路径
    /// - Returns: 用于显示的 SF Symbol 名称
    private func iconForFile(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "md", "txt", "json", "xml", "yaml", "yml": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        case "pdf": return "doc.richtext"
        default: return "doc"
        }
    }
}

// MARK: - Action

extension FileNodeView {
    /// 根据选中与 hover 状态计算当前行背景色
    /// - Parameter isSelected: 当前节点是否被选中
    /// - Returns: 行背景颜色
    fileprivate func rowBackground(isSelected: Bool) -> Color {
        if isSelected {
            return isHovering
            ? Color.accentColor.opacity(0.28)
            : Color.accentColor.opacity(0.22)
        } else {
            return isHovering
            ? Color.primary.opacity(0.06)
            : Color.clear
        }
    }
    
    /// 加载当前目录下的子节点，并按“目录在前”的规则排序
    private func loadChildren() {
        if Self.verbose {
            ProjectTreePlugin.logger.info("\(self.t)loadChildren: \(fileName)")
        }
        
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
                    self.children = sorted
                }
            } catch {
                ProjectTreePlugin.logger.error("\(self.t)loadChildren error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Setter

extension FileNodeView {
    // 当前视图状态较简单，暂不需要单独的 Setter 方法
}

// MARK: - Event Handler

extension FileNodeView {
    // 当前视图未监听外部事件
}

// MARK: - Preview

#Preview("FileNodeView") {
    FileNodeView(
        url: URL(fileURLWithPath: "/tmp"),
        depth: 0,
        selectedURL: nil,
        onSelect: { _ in }
    )
}
