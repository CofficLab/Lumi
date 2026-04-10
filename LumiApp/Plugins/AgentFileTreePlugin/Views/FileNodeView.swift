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

    /// 外部刷新令牌，变化时重新加载子节点
    let refreshToken: Int

    /// 是否为根节点（depth == 0）
    private var isRoot: Bool { depth == 0 }

    /// 本地展开状态
    @State private var isExpanded: Bool = false

    /// 本地子节点缓存
    @State private var children: [URL] = []

    /// 是否正在加载子节点
    @State private var isLoading: Bool = false

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

    /// 文件系统变化监听器（根节点专用）
    @State private var watcher: ProjectTreeWatcher?

    /// 当前正在监控的已展开子目录集合（根节点专用）
    @State private var expandedSubDirectoryURLs: Set<URL> = []

    /// 是否文件夹
    private var isDirectory: Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
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
        if isRoot {
            rootBody
        } else {
            normalNodeBody
        }
    }

    // MARK: - Root Node Body

    @ViewBuilder
    private var rootBody: some View {
        VStack(spacing: 0) {
            // 根节点本身（项目名称）
            rootNodeRow

            // 子节点列表
            if isLoading {
                FileTreeLoadingView()
            } else if children.isEmpty {
                FileTreeEmptyView()
            } else if isExpanded {
                LazyVStack(spacing: 0) {
                    ForEach(children, id: \.self) { childURL in
                        FileNodeView(
                            url: childURL,
                            depth: 1,
                            selectedURL: selectedURL,
                            onSelect: onSelect,
                            refreshToken: refreshToken
                        )
                    }
                }
            }
        }
        .onAppear {
            if !isExpanded { isExpanded = true }
            if children.isEmpty && !isLoading { loadChildren() }
            setupWatcherIfNeeded()
        }
        .onDisappear {
            watcher?.stopAll()
            watcher = nil
        }
        .onChange(of: refreshToken) { _, newValue in
            handleRefreshTokenChange(newValue)
        }
    }

    /// 根节点行视图
    @ViewBuilder
    private var rootNodeRow: some View {
        HStack(spacing: 6) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .frame(width: 10)

            Image(systemName: "folder.fill")
                .font(.system(size: 10))
                .foregroundColor(.accentColor)
                .frame(width: 14)

            Text(url.lastPathComponent)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textPrimary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
                if isExpanded && children.isEmpty && !isLoading {
                    loadChildren()
                }
            }
        }
    }

    // MARK: - Normal Node Body

    @ViewBuilder
    private var normalNodeBody: some View {
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

    // MARK: - Watcher (Root Node Only)

    private func setupWatcherIfNeeded() {
        guard isRoot, watcher == nil else { return }

        let currentURL = url
        watcher = ProjectTreeWatcher { changedURL in
            Task { @MainActor [self] in
                self.handleFileSystemChange(changedURL: changedURL, rootURL: currentURL)
            }
        }
        watcher?.startWatching(url: url)
    }

    private func handleFileSystemChange(changedURL: URL, rootURL: URL) {
        let standardizedChanged = changedURL.standardizedFileURL
        let standardizedRoot = rootURL.standardizedFileURL

        if standardizedChanged.path == standardizedRoot.path {
            reloadChildren()
        }
        lastRefreshToken = refreshToken + 1
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
        isLoading = true
        let currentURL = url
        Task.detached(priority: .userInitiated) { [self] in
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: currentURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: []
                )
                let sorted = ProjectTreeFileService.filterAndSortContents(contents)
                await MainActor.run { [self] in
                    self.children = sorted
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { [self] in
                    self.children = []
                    self.isLoading = false
                }
            }
        }
    }

    private func reloadChildren() { loadChildren() }

    private func createNewFile() {
        guard !newItemName.isEmpty else { return }
        let fileURL = url.appendingPathComponent(newItemName)
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        reloadChildren()
    }

    private func createNewFolder() {
        guard !newItemName.isEmpty else { return }
        let folderURL = url.appendingPathComponent(newItemName)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
        reloadChildren()
    }

    private func renameItem() {
        guard !newItemName.isEmpty else { return }
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newItemName)
        try? FileManager.default.moveItem(at: url, to: newURL)
        onSelect(newURL)
        reloadChildren()
    }

    private func deleteItem() {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        reloadChildren()
    }

    private func openInFinder() {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }

    private func openInVSCode() {
        ProjectTreeFileService.openInVSCode(url)
    }

    private func openInTerminal() {
        ProjectTreeFileService.openInTerminal(url)
    }

    private func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    private func copyRelativePath() {
        let projectPath = projectVM.currentProjectPath
        guard !projectPath.isEmpty else { return }
        let relativePath = url.path.replacingOccurrences(of: projectPath + "/", with: "")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(relativePath, forType: .string)
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