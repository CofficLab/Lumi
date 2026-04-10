import MagicKit
import SwiftUI

/// 文件树节点视图 - 完全独立实现，无外部依赖
struct FileNodeView: View {
    let url: URL
    let depth: Int

    /// 当前选中的文件 URL，用于高亮选中行
    let selectedURL: URL?

    /// 选中某个文件节点的回调
    let onSelect: (URL) -> Void

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
        ProjectTreeFileService.isDirectory(url)
    }

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
        refreshToken: Int = 0
    ) {
        self.url = url
        self.depth = depth
        self.selectedURL = selectedURL
        self.onSelect = onSelect
        self.refreshToken = refreshToken
    }

    // MARK: - Body

    var body: some View {
        let isSelected = selectedURL == url

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                if isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .frame(width: 10)
                } else {
                    Color.clear.frame(width: 10)
                }

                Image(systemName: iconName)
                    .font(.system(size: 10))
                    .foregroundColor(isDirectory ? .accentColor : .secondary)
                    .frame(width: 14)

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
            .background(rowBackground(isSelected: isSelected))
            .contentShape(Rectangle())
            .onDrag { NSItemProvider(object: url as NSURL) } preview: {
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
                LazyVStack(spacing: 0) {
                    ForEach(children, id: \.self) { childURL in
                        FileNodeView(
                            url: childURL,
                            depth: depth + 1,
                            selectedURL: selectedURL,
                            onSelect: onSelect,
                            refreshToken: refreshToken
                        )
                    }
                }
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
        Button { openInFinder() } label: { Label(String(localized: "Reveal in Finder", table: "ProjectTree"), systemImage: "finder") }
        Button { openInVSCode() } label: { Label(String(localized: "Open in VS Code", table: "ProjectTree"), systemImage: "chevron.left.forwardslash.chevron.right") }
        Button { openInTerminal() } label: { Label(String(localized: "Open in Terminal", table: "ProjectTree"), systemImage: "terminal") }
        Divider()
        Button(role: .destructive) { showDeleteConfirmation = true } label: {
            Label(String(localized: "Move to Trash", table: "ProjectTree"), systemImage: "trash")
        }
    }

    // MARK: - Event Handler

    private func handleTap() {
        if isDirectory {
            isExpanded.toggle()
            if isExpanded && children.isEmpty {
                loadChildren()
            }
        }
        onSelect(url)
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
        return ProjectTreeFileService.getFileIcon(for: url)
    }

    fileprivate func rowBackground(isSelected: Bool) -> Color {
        if isSelected {
            return isHovering ? Color.accentColor.opacity(0.28) : Color.accentColor.opacity(0.22)
        } else {
            return isHovering ? Color.primary.opacity(0.06) : Color.clear
        }
    }
}

// MARK: - Actions

extension FileNodeView {
    private func loadChildren() {
        let currentURL = url
        Task.detached(priority: .userInitiated) { [self] in
            do {
                let sorted = try ProjectTreeFileService.loadContents(of: currentURL)
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
        ProjectTreeFileService.createFile(in: url, name: newItemName)
        reloadChildren()
    }

    private func createNewFolder() {
        ProjectTreeFileService.createFolder(in: url, name: newItemName)
        reloadChildren()
    }

    private func renameItem() {
        if let newURL = ProjectTreeFileService.renameItem(at: url, newName: newItemName) {
            onSelect(newURL)
        }
        reloadChildren()
    }

    private func deleteItem() {
        ProjectTreeFileService.trashItem(at: url)
        reloadChildren()
    }

    private func openInFinder() {
        ProjectTreeFileService.openInFinder(url)
    }

    private func openInVSCode() {
        ProjectTreeFileService.openInVSCode(url)
    }

    private func openInTerminal() {
        ProjectTreeFileService.openInTerminal(url)
    }
}

// MARK: - Preview

#Preview {
    let testURL = URL(fileURLWithPath: NSHomeDirectory())

    return FileNodeView(
        url: testURL,
        depth: 0,
        selectedURL: nil,
        onSelect: { _ in }
    )
    .frame(width: 250, height: 400)
}
