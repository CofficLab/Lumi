import SwiftUI
import MagicKit
import UniformTypeIdentifiers
import OSLog

/// 项目文件树节点视图
struct FileTreeNodeView: View, SuperLog {
    nonisolated static let emoji = "🌿"
    nonisolated static let verbose = true

    let node: FileTreeNode
    let depth: Int
    let projectPath: String
    let isSelected: Bool  // 通过参数传递选中状态，而不是依赖 EnvironmentObject
    let onFileDrop: (URL) -> Void
    let onFileSelect: (URL) -> Void

    @State private var isExpanded = false
    @State private var children: [FileTreeNode] = []
    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    @State private var isHovered = false
    
    /// 每层缩进量 (参考 VS Code 的默认缩进)
    private let indentPerLevel: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 节点行
            nodeRow

            // 子节点或加载状态
            if isExpanded && node.isDirectory {
                if isLoading {
                    loadingIndicator
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, indentPerLevel)
                        .padding(.vertical, 4)
                } else {
                    childNodes
                }
            }
        }
        .task {
            await handleOnAppear()
        }
    }
    
    private func handleOnAppear() async {
        // 首次出现时，从状态管理器恢复展开状态
        if !hasLoadedOnce {
            hasLoadedOnce = true
            let savedState = FileTreeStateManager.shared.isExpanded(url: node.url, projectPath: projectPath)
            if Self.verbose {
                os_log("\(Self.t)👁️ [\(node.name)] onAppear - savedState=\(savedState)")
            }
            if savedState {
                // 使用 async 将状态修改推迟到下一个 run loop，避免在视图更新期间修改状态
                await MainActor.run {
                    self.isExpanded = true
                }
                // 如果之前是展开的，并且还没有数据，则异步加载
                if children.isEmpty && !isLoading {
                    if Self.verbose {
                        os_log("\(Self.t)📂 [\(node.name)] 恢复展开状态并加载子节点")
                    }
                    await loadChildrenAsync()
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
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            handleHover(hovering)
        }
        .onTapGesture {
            handleTap()
        }
        // 添加拖拽支持 - 强制转换为普通纯文本字符串传递，避免系统为 fileURL 生成 Caches 目录下的替身文件
        .onDrag {
            if Self.verbose {
                os_log("\(Self.t)🎯 开始拖拽: \(node.name)")
            }
            // 将真实路径作为普通字符串拖出
            return NSItemProvider(object: node.url.path as NSString)
        }
    }
    
    private func handleHover(_ hovering: Bool) {
        isHovered = hovering
    }

    /// 背景色：根据选中状态和 hover 状态返回不同颜色
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isHovered {
            return Color.primary.opacity(0.08)
        }
        return Color.clear
    }

    private var expandCollapseButton: some View {
        Button(action: {
            if Self.verbose {
                os_log("\(Self.t)🔘 [\(node.name)] 展开/折叠按钮点击")
            }
            toggle()
        }) {
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
    }

    // MARK: - Child Nodes

    private var childNodes: some View {
        Group {
            ForEach(children) { child in
                FileTreeNodeView(
                    node: child,
                    depth: depth + 1,
                    projectPath: projectPath,
                    isSelected: isSelected,  // 传递选中状态给子节点
                    onFileDrop: onFileDrop,
                    onFileSelect: onFileSelect
                )
            }
        }
        .padding(.leading, indentPerLevel)
    }

    // MARK: - Actions

    private func handleTap() {
        if node.isDirectory {
            if Self.verbose {
                os_log("\(Self.t)👆 [\(node.name)] 点击文件夹")
            }
            toggle()
        } else {
            if Self.verbose {
                os_log("\(Self.t)👆 [\(node.name)] 点击文件")
            }
            // 选择文件
            onFileSelect(node.url)
        }
    }

    private func toggle() {
        let oldValue = isExpanded
        isExpanded.toggle()
        
        if Self.verbose {
            os_log("\(Self.t)\(isExpanded ? "📂" : "📁") [\(node.name)] 从 \(oldValue) 变为 \(isExpanded)")
        }
        
        // 保存状态到持久化存储
        FileTreeStateManager.shared.setExpanded(isExpanded, url: node.url, projectPath: projectPath)
        
        if isExpanded && children.isEmpty && !isLoading {
            loadChildren()
        }
    }

    private func loadChildren() {
        isLoading = true
        
        if Self.verbose {
            os_log("\(Self.t)⏳ [\(node.name)] 开始加载子节点")
        }
        
        Task {
            let startTime = Date()
            let loadedChildren = await loadChildrenAsync()
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                children = loadedChildren
                isLoading = false
                if Self.verbose {
                    os_log("\(Self.t)✅ [\(node.name)] 子节点加载完成: \(loadedChildren.count) 个, 耗时 \(String(format: "%.3f", duration))s")
                }
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

            if Self.verbose {
                os_log("\(Self.t)📂 [\(node.name)] 读取目录包含 \(contents.count) 个项")
            }

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
                    if Self.verbose {
                        os_log("\(Self.t)⚠️ 读取子文件信息失败: \(fileURL.lastPathComponent), error: \(error.localizedDescription)")
                    }
                    continue
                }
            }
        } catch {
            if Self.verbose {
                os_log("\(Self.t)❌ 读取子目录失败: \(node.name), error: \(error.localizedDescription)")
            }
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
