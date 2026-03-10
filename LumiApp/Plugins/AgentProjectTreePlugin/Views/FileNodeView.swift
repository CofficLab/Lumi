import SwiftUI
import MagicKit
import OSLog

/// 文件树节点视图 - 自定义递归布局
struct FileNodeView: View, SuperLog {
    /// 日志前缀的表情符号（文件树节点）
    nonisolated static let emoji = "📁"
    
    /// 是否输出详细日志
    nonisolated static let verbose = false
    
    let url: URL
    let depth: Int
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
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .padding(.leading, CGFloat(depth) * 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isHovering
                ? Color.primary.opacity(0.06)
                : Color.clear
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if isDirectory {
                    isExpanded.toggle()
                    if isExpanded && children.isEmpty {
                        loadChildren()
                    }
                } else {
                    onSelect(url)
                }
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
    /// 加载当前目录下的子节点，并按“目录在前”的规则排序
    private func loadChildren() {
        if Self.verbose {
            os_log("\(self.t)loadChildren: \(fileName)")
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
                os_log(.error, "\(self.t)loadChildren error: \(error.localizedDescription)")
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
        onSelect: { _ in }
    )
}
