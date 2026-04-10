import MagicKit
import os
import SwiftUI

/// 文件树节点视图 - 完全独立实现，无外部依赖
struct FileNodeView: View {
    /// 环境对象，用于获取项目路径
    @EnvironmentObject private var projectVM: ProjectVM
    /// 日志前缀的表情符号（文件树节点）
    nonisolated static let emoji = "📁"

    let url: URL
    let depth: Int

    /// 当前选中的文件 URL，用于高亮选中行
    let selectedURL: URL?

    /// 选中某个文件节点的回调
    let onSelect: (URL) -> Void

    /// 目录展开时的回调（用于注册文件系统监听）
    let onDirectoryExpanded: ((URL) -> Void)?

    /// 目录折叠时的回调（用于取消文件系统监听）
    let onDirectoryCollapsed: ((URL) -> Void)?

    /// 外部刷新令牌，变化时重新加载子节点
    let refreshToken: Int

    /// 本地展开状态
    @State private var isExpanded: Bool = false

    /// 本地子节点缓存
    @State private var children: [URL] = []

    /// 是否处于 hover 状态（用于高亮当前行）
    @State private var isHovering: Bool = false

    /// 删除确认对话框
    @State private var showDeleteConfirmation: Bool = false

    /// 新建文件对话框
    @State private var showNewFileSheet: Bool = false

    /// 新建文件夹对话框
    @State private var showNewFolderSheet: Bool = false

    /// 重命名对话框
    @State private var showRenameSheet: Bool = false

    /// 新项目名称输入
    @State private var newItemName: String = ""

    /// 记录上次刷新令牌的值，用于判断是否需要重新加载
    @State private var lastRefreshToken: Int = 0

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
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
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
            .onDrag {
                // 直接返回 NSURL 对象，这样可以保持真实的文件路径引用
                // 避免创建临时缓存文件
                NSItemProvider(object: url as NSURL)
            } preview: {
                // 拖拽预览
                DragPreview(fileURL: url)
            }
            .contextMenu {
                // 新建菜单（仅文件夹显示）
                if isDirectory {
                    Button {
                        newItemName = ""
                        showNewFileSheet = true
                    } label: {
                        Label(String(localized: "New File", table: "ProjectTree"), systemImage: "doc.badge.plus")
                    }

                    Button {
                        newItemName = ""
                        showNewFolderSheet = true
                    } label: {
                        Label(String(localized: "New Folder", table: "ProjectTree"), systemImage: "folder.badge.plus")
                    }

                    Divider()
                }

                // 重命名（文件和文件夹都显示）
                Button {
                    newItemName = fileName
                    // 延迟弹出对话框，确保 newItemName 已更新
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        showRenameSheet = true
                    }
                } label: {
                    Label(String(localized: "Rename", table: "ProjectTree"), systemImage: "pencil")
                }

                Divider()

                Button {
                    openInFinder()
                } label: {
                    Label(String(localized: "Reveal in Finder", table: "ProjectTree"), systemImage: "finder")
                }

                Button {
                    openInVSCode()
                } label: {
                    Label(String(localized: "Open in VS Code", table: "ProjectTree"), systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Button {
                    openInTerminal()
                } label: {
                    Label(String(localized: "Open in Terminal", table: "ProjectTree"), systemImage: "terminal")
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(String(localized: "Move to Trash", table: "ProjectTree"), systemImage: "trash")
                }
            }
            .onTapGesture {
                handleTap()
            }
            .onHover { hovering in
                isHovering = hovering
            }
            .confirmationDialog(
                String(localized: "Are you sure you want to delete \"\(fileName)\"?", table: "ProjectTree"),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Move to Trash", table: "ProjectTree"), role: .destructive) {
                    deleteItem()
                }
                Button(String(localized: "Cancel", table: "ProjectTree"), role: .cancel) {}
            } message: {
                Text(String(localized: "This item will be moved to the Trash.", table: "ProjectTree"))
            }
            // 新建文件对话框
            .alert(
                String(localized: "New File", table: "ProjectTree"),
                isPresented: $showNewFileSheet
            ) {
                TextField(String(localized: "File name", table: "ProjectTree"), text: $newItemName)
                Button(String(localized: "Create", table: "ProjectTree")) {
                    createNewFile()
                }
                Button(String(localized: "Cancel", table: "ProjectTree"), role: .cancel) {}
            } message: {
                Text(String(localized: "Enter the name for the new file.", table: "ProjectTree"))
            }
            // 新建文件夹对话框
            .alert(
                String(localized: "New Folder", table: "ProjectTree"),
                isPresented: $showNewFolderSheet
            ) {
                TextField(String(localized: "Folder name", table: "ProjectTree"), text: $newItemName)
                Button(String(localized: "Create", table: "ProjectTree")) {
                    createNewFolder()
                }
                Button(String(localized: "Cancel", table: "ProjectTree"), role: .cancel) {}
            } message: {
                Text(String(localized: "Enter the name for the new folder.", table: "ProjectTree"))
            }
            // 重命名对话框
            .alert(
                String(localized: "Rename", table: "ProjectTree"),
                isPresented: $showRenameSheet
            ) {
                TextField(String(localized: "New name", table: "ProjectTree"), text: $newItemName)
                Button(String(localized: "Rename", table: "ProjectTree")) {
                    renameItem()
                }
                Button(String(localized: "Cancel", table: "ProjectTree"), role: .cancel) {}
            } message: {
                Text(String(localized: "Enter the new name for this item.", table: "ProjectTree"))
            }

            if isDirectory && isExpanded && !children.isEmpty {
                VStack(spacing: 0) {
                    ForEach(children, id: \.self) { childURL in
                        FileNodeView(
                            url: childURL,
                            depth: depth + 1,
                            selectedURL: selectedURL,
                            onSelect: onSelect,
                            onDirectoryExpanded: onDirectoryExpanded,
                            onDirectoryCollapsed: onDirectoryCollapsed,
                            refreshToken: refreshToken
                        )
                    }
                }
            }
        }
        .onChange(of: refreshToken) { _, newValue in
            guard newValue != lastRefreshToken else { return }
            lastRefreshToken = newValue
            if isDirectory && isExpanded {
                reloadChildren()
            }
        }
    }
}

// MARK: - Event Handler

extension FileNodeView {
    /// 处理点击事件
    private func handleTap() {
        if isDirectory {
            isExpanded.toggle()
            if isExpanded {
                onDirectoryExpanded?(url)
                if children.isEmpty {
                    loadChildren()
                }
            } else {
                onDirectoryCollapsed?(url)
            }
        }
        onSelect(url)
    }

    /// 处理右键菜单操作
    private func handleContextMenuAction(_ action: FileContextMenuAction) {
        switch action {
        case .newFile:
            newItemName = ""
            showNewFileSheet = true
        case .newFolder:
            newItemName = ""
            showNewFolderSheet = true
        case .rename:
            newItemName = fileName
            // 延迟弹出对话框，确保 newItemName 已更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                showRenameSheet = true
            }
        case .revealInFinder:
            openInFinder()
        case .openInVSCode:
            openInVSCode()
        case .openInTerminal:
            openInTerminal()
        case .delete:
            showDeleteConfirmation = true
        case .copyPath:
            copyPath()
        case .copyRelativePath:
            copyRelativePath()
        }
    }

    /// 处理刷新令牌变化
    private func handleRefreshTokenChange(_ newValue: Int) {
        guard newValue != lastRefreshToken else { return }
        lastRefreshToken = newValue
        if isDirectory && isExpanded {
            reloadChildren()
        }
    }

    /// 处理拖拽开始
    private func handleDragStart() -> NSItemProvider {
        // 直接返回 NSURL 对象，这样可以保持真实的文件路径引用
        // 避免创建临时缓存文件
        return NSItemProvider(object: url as NSURL)
    }
}

// MARK: - View Helpers

extension FileNodeView {
    /// 当前节点对应的系统图标名称
    private var iconName: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }
        return ProjectTreeFileService.getFileIcon(for: url)
    }

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
}

// MARK: - Actions

extension FileNodeView {
    /// 加载当前目录下的子节点，并按"目录在前"的规则排序
    private func loadChildren() {
        Task.detached(priority: .userInitiated) {
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: []
                )

                // 使用 Service 进行过滤和排序
                let sorted = ProjectTreeFileService.filterAndSortContents(contents)

                await MainActor.run {
                    self.children = sorted
                }
            } catch {
                // 忽略错误
            }
        }
    }

    /// 重新加载子节点（文件系统变化后调用）
    private func reloadChildren() {
        Task.detached(priority: .userInitiated) {
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: []
                )

                // 使用 Service 进行过滤和排序
                let sorted = ProjectTreeFileService.filterAndSortContents(contents)

                await MainActor.run {
                    self.children = sorted
                }
            } catch {
                // 目录可能已被删除，折叠该节点
                await MainActor.run {
                    self.children = []
                    self.isExpanded = false
                }
            }
        }
    }

    /// 在 Finder 中显示文件/文件夹
    private func openInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// 在 VS Code 中打开文件/文件夹
    private func openInVSCode() {
        ProjectTreeFileService.openInVSCode(url)
    }

    /// 在终端中打开（打开目录或文件所在目录）
    private func openInTerminal() {
        ProjectTreeFileService.openInTerminal(url)
    }

    /// 删除文件/文件夹（移到废纸篓）
    private func deleteItem() {
        do {
            // 移动到废纸篓
            var resultURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
        } catch {
            // 忽略错误
        }
    }

    /// 新建文件
    private func createNewFile() {
        guard !newItemName.isEmpty else { return }

        // 确定目标目录：如果是文件夹，在当前目录下创建；如果是文件，在父目录下创建
        let targetDirectory = isDirectory ? url : url.deletingLastPathComponent()
        let newFileURL = targetDirectory.appendingPathComponent(newItemName)

        // 创建空文件（FileManager.createFile 不抛出错误）
        let success = FileManager.default.createFile(atPath: newFileURL.path, contents: nil, attributes: nil)
        if success {
            // 如果是文件夹且未展开，先展开它
            if isDirectory && !isExpanded {
                isExpanded = true
                onDirectoryExpanded?(url)
            }

            // 立即重新加载子节点
            reloadChildren()
        }
    }

    /// 新建文件夹
    private func createNewFolder() {
        guard !newItemName.isEmpty else { return }

        // 确定目标目录：如果是文件夹，在当前目录下创建；如果是文件，在父目录下创建
        let targetDirectory = isDirectory ? url : url.deletingLastPathComponent()
        let newFolderURL = targetDirectory.appendingPathComponent(newItemName)

        do {
            // 创建文件夹
            try FileManager.default.createDirectory(at: newFolderURL, withIntermediateDirectories: false)

            // 如果是文件夹且未展开，先展开它
            if isDirectory && !isExpanded {
                isExpanded = true
                onDirectoryExpanded?(url)
            }

            // 立即重新加载子节点
            reloadChildren()
        } catch {
            // 忽略错误
        }
    }

    /// 重命名文件/文件夹
    private func renameItem() {
        guard !newItemName.isEmpty else { return }
        guard newItemName != fileName else { return } // 名称未改变，无需操作

        // 构建新的 URL
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newItemName)

        do {
            // 使用 FileManager 移动文件到新路径（即重命名）
            try FileManager.default.moveItem(at: url, to: newURL)
        } catch {
            // 忽略错误
        }
    }

    /// 复制文件路径到剪贴板
    private func copyPath() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
    }

    /// 复制相对路径到剪贴板
    private func copyRelativePath() {
        let rootPath = projectVM.currentProjectPath
        guard !rootPath.isEmpty else { return }

        let relativePath = url.path
            .replacingOccurrences(of: rootPath, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(relativePath, forType: .string)
    }
}
