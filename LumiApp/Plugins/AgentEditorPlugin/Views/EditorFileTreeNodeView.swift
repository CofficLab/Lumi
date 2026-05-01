import MagicKit
import SwiftUI

/// 文件树节点视图 - 完全独立实现，无外部依赖
struct EditorFileTreeNodeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let url: URL
    let depth: Int

    /// 当前选中的文件 URL，用于高亮选中行
    let selectedURL: URL?

    /// 选中某个文件节点的回调
    let onSelect: (URL) -> Void

    /// 外部刷新令牌，变化时重新加载子节点
    let refreshToken: Int

    /// 项目根目录路径，用于计算相对路径和存储展开状态
    let projectRootPath: String

    /// 展开/折叠变化回调，通知协调器更新文件系统监听列表
    let onExpansionChange: ((String, Bool) -> Void)?

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

    /// 是否文件夹（启动时缓存，避免 body 求值时反复调 FileManager）
    private let isDirectory: Bool

    /// 文件名（不含路径）
    private var fileName: String {
        url.lastPathComponent
    }

    // MARK: - Init

    init(
        url: URL,
        depth: Int,
        selectedURL: URL? = nil,
        onSelect: @escaping (URL) -> Void,
        refreshToken: Int = 0,
        projectRootPath: String = "",
        onExpansionChange: ((String, Bool) -> Void)? = nil
    ) {
        self.url = url
        self.depth = depth
        self.selectedURL = selectedURL
        self.onSelect = onSelect
        self.refreshToken = refreshToken
        self.projectRootPath = projectRootPath
        self.onExpansionChange = onExpansionChange

        // 在 init 时一次性缓存 isDirectory，避免 body 求值时反复做文件系统 I/O
        self.isDirectory = EditorFileTreeService.isDirectory(url)

        // 从 store 恢复展开状态
        if !projectRootPath.isEmpty {
            let relativePath = url.path.replacingOccurrences(of: projectRootPath, with: "")
            let store = EditorFileTreeStore.shared
            _isExpanded = State(initialValue: store.expandedPaths(for: projectRootPath).contains(relativePath))
        }
    }

    // MARK: - Body

    var body: some View {
        let isSelected = selectedURL == url
        let theme = themeManager.activeAppTheme

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                if isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(theme.workspaceSecondaryTextColor())
                        .frame(width: 12)
                } else {
                    Color.clear.frame(width: 12)
                }

                Image(systemName: iconName)
                    .font(.system(size: 12))
                    .foregroundColor(isDirectory ? theme.accentColors().primary : theme.workspaceSecondaryTextColor())
                    .frame(width: 16)

                Text(fileName)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? theme.sidebarSelectionTextColor() : theme.workspaceTextColor())
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .padding(.leading, CGFloat(depth) * 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground(isSelected: isSelected))
            .contentShape(Rectangle())
            .onDrag {
                // 传递纯文本路径字符串，接收方直接拿到绝对路径，不会触发文件缓存复制
                NSItemProvider(object: url.path as NSString)
            } preview: {
                DragPreview(fileURL: url)
            }
            .contextMenu { contextMenuContent }
            .onTapGesture { handleTap() }
            .onHover { hovering in isHovering = hovering }
            .confirmationDialog(
                String(localized: "Are you sure you want to delete \"\(fileName)\"?", table: "ProjectTree"),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Move to Trash", table: "ProjectTree"), role: .destructive) { deleteItem() }
                Button(String(localized: "Cancel", table: "ProjectTree"), role: .cancel) {}
            } message: {
                Text(String(localized: "This item will be moved to the Trash.", table: "ProjectTree"))
            }
            .alert(String(localized: "New File", table: "ProjectTree"), isPresented: $showNewFileSheet) {
                TextField(String(localized: "File name", table: "ProjectTree"), text: $newItemName)
                Button(String(localized: "Create", table: "ProjectTree")) { createNewFile() }
                Button(String(localized: "Cancel", table: "ProjectTree"), role: .cancel) {}
            } message: { Text(String(localized: "Enter the name for the new file.", table: "ProjectTree")) }
            .alert(String(localized: "New Folder", table: "ProjectTree"), isPresented: $showNewFolderSheet) {
                TextField(String(localized: "Folder name", table: "ProjectTree"), text: $newItemName)
                Button(String(localized: "Create", table: "ProjectTree")) { createNewFolder() }
                Button(String(localized: "Cancel", table: "ProjectTree"), role: .cancel) {}
            } message: { Text(String(localized: "Enter the name for the new folder.", table: "ProjectTree")) }
            .alert(String(localized: "Rename", table: "ProjectTree"), isPresented: $showRenameSheet) {
                TextField(String(localized: "New name", table: "ProjectTree"), text: $newItemName)
                Button(String(localized: "Rename", table: "ProjectTree")) { renameItem() }
                Button(String(localized: "Cancel", table: "ProjectTree"), role: .cancel) {}
            } message: { Text(String(localized: "Enter the new name for this item.", table: "ProjectTree")) }

            // 子节点
            if isDirectory && isExpanded && !children.isEmpty {
                VStack(spacing: 2) {
                    ForEach(children, id: \.self) { childURL in
                        EditorFileTreeNodeView(
                            url: childURL,
                            depth: depth + 1,
                            selectedURL: selectedURL,
                            onSelect: onSelect,
                            refreshToken: refreshToken,
                            projectRootPath: projectRootPath,
                            onExpansionChange: onExpansionChange
                        )
                    }
                }
            }
        }
        .onAppear {
            // 恢复展开状态时，children 尚未加载，需要补加载
            if isDirectory && isExpanded && children.isEmpty {
                loadChildren()
            }
            // 恢复展开状态时通知协调器（用于文件系统监听）
            if isDirectory && isExpanded {
                notifyExpansionChanged(isExpanded: true)
            }
        }
        .onChange(of: refreshToken) { _, newValue in
            handleRefreshTokenChange(newValue)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
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

        Button {
            newItemName = fileName
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { showRenameSheet = true }
        } label: {
            Label(String(localized: "Rename", table: "ProjectTree"), systemImage: "pencil")
        }

        Divider()
        Button { addToConversation() } label: {
            Label(String(localized: "Add to Conversation", table: "ProjectTree"), systemImage: "bubble.left.and.bubble.right")
        }
        Button { openInFinder() } label: { Label(String(localized: "Reveal in Finder", table: "ProjectTree"), systemImage: "finder") }
        Button { openInVSCode() } label: { Label(String(localized: "Open in VS Code", table: "ProjectTree"), systemImage: "chevron.left.forwardslash.chevron.right") }
        Button { openInTerminal() } label: { Label(String(localized: "Open in Terminal", table: "ProjectTree"), systemImage: "terminal") }
        Button { copyPath() } label: { Label(String(localized: "Copy Path", table: "ProjectTree"), systemImage: "doc.on.doc") }
        Divider()
        Button(role: .destructive) { showDeleteConfirmation = true } label: {
            Label(String(localized: "Move to Trash", table: "ProjectTree"), systemImage: "trash")
        }
    }

    // MARK: - Event Handler

    private func handleTap() {
        if isDirectory {
            isExpanded.toggle()
            persistExpansionState()
            notifyExpansionChanged(isExpanded: isExpanded)
            if isExpanded && children.isEmpty {
                loadChildren()
            }
        } else {
            onSelect(url)
        }
    }

    private func handleRefreshTokenChange(_ newValue: Int) {
        guard newValue != lastRefreshToken else { return }
        lastRefreshToken = newValue
        if isDirectory && isExpanded {
            reloadChildren()
        }
    }

    // MARK: - View Helpers

    private var iconName: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }
        return EditorFileTreeService.getFileIcon(for: url)
    }

    fileprivate func rowBackground(isSelected: Bool) -> Color {
        let theme = themeManager.activeAppTheme
        if isSelected {
            return isHovering ? theme.sidebarSelectionColor().opacity(1.2) : theme.sidebarSelectionColor()
        } else {
            return isHovering ? theme.workspaceTextColor().opacity(0.06) : Color.clear
        }
    }
}

// MARK: - Actions

extension EditorFileTreeNodeView {
    // MARK: - Expansion Persistence

    /// 当前节点相对于项目根目录的路径
    private var relativePath: String {
        url.path.replacingOccurrences(of: projectRootPath, with: "")
    }

    /// 将当前展开/折叠状态持久化到 store
    private func persistExpansionState() {
        guard !projectRootPath.isEmpty else { return }
        let store = EditorFileTreeStore.shared
        if isExpanded {
            store.addExpandedPath(relativePath, for: projectRootPath)
        } else {
            store.removeExpandedPath(relativePath, for: projectRootPath)
        }
    }

    /// 通知协调器展开状态变化（用于更新文件系统监听列表）
    private func notifyExpansionChanged(isExpanded: Bool) {
        guard !projectRootPath.isEmpty, isDirectory else { return }
        onExpansionChange?(relativePath, isExpanded)
    }

    // MARK: - Data Loading
    private func loadChildren() {
        let currentURL = url
        Task.detached(priority: .userInitiated) { [self] in
            do {
                let sorted = try EditorFileTreeService.loadContents(of: currentURL)
                await MainActor.run { [self] in
                    self.children = sorted
                }
            } catch {
                await MainActor.run { [self] in
                    self.children = []
                }
            }
        }
    }

    private func reloadChildren() { loadChildren() }

    private func createNewFile() {
        EditorFileTreeService.createFile(in: url, name: newItemName)
        reloadChildren()
    }

    private func createNewFolder() {
        EditorFileTreeService.createFolder(in: url, name: newItemName)
        reloadChildren()
    }

    private func renameItem() {
        if let newURL = EditorFileTreeService.renameItem(at: url, newName: newItemName) {
            onSelect(newURL)
        }
        reloadChildren()
    }

    private func deleteItem() {
        EditorFileTreeService.trashItem(at: url)
        reloadChildren()
    }

    private func openInFinder() {
        EditorFileTreeService.openInFinder(url)
    }

    private func openInVSCode() {
        EditorFileTreeService.openInVSCode(url)
    }

    private func openInTerminal() {
        EditorFileTreeService.openInTerminal(url)
    }

    private func copyPath() {
        EditorFileTreeService.copyPath(url)
    }

    /// 与拖入输入区相同：图片走附件，其它文件插入路径
    private func addToConversation() {
        NotificationCenter.postFileDroppedToChat(fileURL: url)
    }
}

// MARK: - Preview

#Preview {
    let testURL = URL(fileURLWithPath: NSHomeDirectory())

    return EditorFileTreeNodeView(
        url: testURL,
        depth: 0,
        selectedURL: nil,
        onSelect: { _ in }
    )
    .frame(width: 250, height: 400)
}
