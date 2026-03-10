import SwiftUI
import MagicKit
import OSLog

/// 文件树节点视图 - 使用 DisclosureGroup
struct FileNodeView: View {
    let url: URL
    let depth: Int
    let onSelect: (URL) -> Void
    
    /// 本地展开状态
    @State private var isExpanded: Bool = false
    
    /// 本地子节点缓存
    @State private var children: [URL] = []
    
    /// 唯一ID用于追踪
    private let nodeId = UUID()
    
    /// 是否文件夹
    private var isDirectory: Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
    
    /// 文件名
    private var fileName: String {
        url.lastPathComponent
    }
    
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "FileTreeNodeView")
    
    var body: some View {
        if isDirectory {
            DisclosureGroup(
                isExpanded: $isExpanded,
                content: {
                    if !children.isEmpty {
                        ForEach(children, id: \.self) { childURL in
                            FileNodeView(
                                url: childURL,
                                depth: depth + 1,
                                onSelect: onSelect
                            )
                        }
                    }
                },
                label: {
                    nodeRow
                }
            )
            .onChange(of: isExpanded) { _, newValue in
                if newValue && children.isEmpty {
                    loadChildren()
                }
            }
        } else {
            nodeRow
        }
    }
    
    // MARK: - Node Row
    
    private var nodeRow: some View {
        HStack(spacing: 6) {
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
        .padding(.horizontal, 0)
        .padding(.vertical, 3)
        .onTapGesture {
            if !isDirectory {
                onSelect(url)
            }
        }
    }
    
    // MARK: - Icon
    
    private var iconName: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }
        return iconForFile(url)
    }
    
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
    
    // MARK: - Load Children
    
    private func loadChildren() {
        logger.info("📂 [\(nodeId)] loadChildren: \(fileName)")
        
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
                logger.error("❌ [\(nodeId)] loadChildren error: \(error.localizedDescription)")
            }
        }
    }
}
