import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

/// 文件树节点视图，负责单个文件或目录行的展示和交互
public struct NodeView: View, Equatable {
    /// 默认图标主题贡献器（无状态，可复用）
    private static let defaultIconContributor = LumiDefaultFileIconThemeContributor()
    
    @EnvironmentObject private var editorContext: EditorContext
    @EnvironmentObject private var selectionState: SelectionState
    @LumiTheme private var uiTheme
    public let url: URL
    public let depth: Int

    /// 选中某个文件节点的回调
    public let onSelect: (URL) -> Void

    /// 当前文件树所属窗口 ID，用于将文件添加到对应窗口的聊天输入。
    public let windowId: UUID?

    /// 外部刷新令牌，变化时重新加载子节点
    public let refreshToken: Int

    /// 项目根目录路径，用于计算相对路径和存储展开状态
    public let projectRootPath: String

    /// 展开/折叠变化回调，通知协调器更新文件系统监听列表
    public let onExpansionChange: ((String, Bool) -> Void)?

    /// 文件树内容变化回调，通知根视图刷新展开目录
    public let onTreeMutation: (() -> Void)?

    /// Git 状态快照（由协调器提供，节点视图只读查询）
    public let gitStatusSnapshot: GitStatusSnapshot

    /// 精准刷新令牌：协调器检测到具体目录变化时递增。
    /// 节点结合 `changedDirectoryPaths` 判断自身是否需要 reload，避免全树重载。
    public let targetedRefreshToken: Int

    /// 最近一次精准刷新命中的目录绝对路径集合（标准化后）。
    /// 节点仅当自身 url 命中此集合时才 reloadChildren。
    public let changedDirectoryPaths: Set<String>

    /// 展开状态（从 store 恢复，用于 Equatable 比较）
    private let expandedFromStore: Bool

    /// 本地展开状态（响应用户交互）
    @State private var isExpanded: Bool

    /// 本地子节点缓存
    @State private var children: [URL] = []

    /// 当前目录是否正在加载子节点
    @State private var isLoadingChildren: Bool = false

    /// 当前目录是否已经完成过至少一次子节点加载
    @State private var hasLoadedChildren: Bool = false

    /// 当前目录加载任务
    @State private var loadChildrenTask: Task<Void, Never>?

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

    /// 文件图标解析元数据（启动时缓存，避免 body 求值时反复调 FileManager）
    private let iconMetadata: FileTreeIconMetadata

    /// Git 相对路径（启动时缓存，避免 body 求值时反复调 PathFormatter）
    private let gitRelativePath: String

    /// 文件名（不含路径）
    private var fileName: String {
        url.lastPathComponent
    }

    // MARK: - Equatable

    public nonisolated static func == (lhs: NodeView, rhs: NodeView) -> Bool {
        // 比较影响视图渲染的所有外部属性，包括从 store 恢复的展开状态
        return lhs.url == rhs.url
            && lhs.depth == rhs.depth
            && lhs.refreshToken == rhs.refreshToken
            && lhs.targetedRefreshToken == rhs.targetedRefreshToken
            && lhs.changedDirectoryPaths == rhs.changedDirectoryPaths
            && lhs.gitStatusSnapshot == rhs.gitStatusSnapshot
            && lhs.windowId == rhs.windowId
            && lhs.projectRootPath == rhs.projectRootPath
            && lhs.expandedFromStore == rhs.expandedFromStore
    }

    // MARK: - Init

    public init(
        url: URL,
        depth: Int,
        onSelect: @escaping (URL) -> Void,
        windowId: UUID? = nil,
        refreshToken: Int = 0,
        projectRootPath: String = "",
        onExpansionChange: ((String, Bool) -> Void)? = nil,
        onTreeMutation: (() -> Void)? = nil,
        gitStatusSnapshot: GitStatusSnapshot = .empty,
        targetedRefreshToken: Int = 0,
        changedDirectoryPaths: Set<String> = []
    ) {
        self.url = url
        self.depth = depth
        self.onSelect = onSelect
        self.windowId = windowId
        self.refreshToken = refreshToken
        self.projectRootPath = projectRootPath
        self.onExpansionChange = onExpansionChange
        self.onTreeMutation = onTreeMutation
        self.gitStatusSnapshot = gitStatusSnapshot
        self.targetedRefreshToken = targetedRefreshToken
        self.changedDirectoryPaths = changedDirectoryPaths

        // 在 init 时一次性缓存 isDirectory，避免 body 求值时反复做文件系统 I/O
        self.isDirectory = FileTreeFacade.isDirectory(url)
        self.iconMetadata = FileTreeIconMetadata(
            fileName: url.lastPathComponent,
            fileExtension: url.pathExtension.lowercased(),
            isDirectory: self.isDirectory,
            isSwiftPackageDirectory: self.isDirectory && FileManager.default.fileExists(
                atPath: url.appendingPathComponent("Package.swift", isDirectory: false).path
            )
        )

        // 在 init 时一次性缓存 Git 相对路径，避免 body 求值时反复调 PathFormatter
        self.gitRelativePath = PathFormatter.gitPath(for: url, projectRootPath: projectRootPath)

        // 从 store 恢复展开状态
        var storedExpanded = false
        if !projectRootPath.isEmpty {
            let relativePath = PathFormatter.expansionPath(for: url, projectRootPath: projectRootPath)
            let store = FileTreeSettings.shared
            storedExpanded = store.expandedPaths(for: projectRootPath).contains(relativePath)
        }
        self.expandedFromStore = storedExpanded
        self._isExpanded = State(initialValue: storedExpanded)
    }

    // MARK: - Body

    public var body: some View {
        let isSelected = selectionState.isSelected(url)
        let icon = resolvedIcon
        let gitStatus = currentGitStatus
        Group {
            if let chrome = editorContext.activeChromeTheme {
                VStack(alignment: .leading, spacing: 0) {
                    rowContent(isSelected: isSelected, icon: icon, gitStatus: gitStatus, chrome: chrome)

                    if isDirectory && isExpanded {
                        if children.isEmpty {
                            if isLoadingChildren {
                                EditorFileTreeLoadingView(depth: depth + 1)
                            } else if hasLoadedChildren {
                                EditorFileTreeEmptyView(depth: depth + 1)
                            }
                        } else {
                            VStack(spacing: 2) {
                                ForEach(children, id: \.self) { childURL in
                                    NodeView(
                                        url: childURL,
                                        depth: depth + 1,
                                        onSelect: onSelect,
                                        windowId: windowId,
                                        refreshToken: refreshToken,
                                        projectRootPath: projectRootPath,
                                        onExpansionChange: onExpansionChange,
                                        onTreeMutation: onTreeMutation,
                                        gitStatusSnapshot: gitStatusSnapshot,
                                        targetedRefreshToken: targetedRefreshToken,
                                        changedDirectoryPaths: changedDirectoryPaths
                                    )
                                    .equatable()
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    selectionState.trackVisible(url)
                    if isDirectory && isExpanded && children.isEmpty {
                        loadChildren()
                    }
                    if isDirectory && isExpanded {
                        notifyExpansionChanged(isExpanded: true)
                    }
                }
                .onChange(of: refreshToken) { _, newValue in
                    handleRefreshTokenChange(newValue)
                }
                .onChange(of: targetedRefreshToken) { _, _ in
                    handleTargetedRefresh()
                }
                .onDisappear {
                    selectionState.untrackVisible(url)
                    loadChildrenTask?.cancel()
                    loadChildrenTask = nil
                }
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func rowContent(isSelected: Bool, icon: LumiFileIcon, gitStatus: GitStatus?, chrome: any LumiAppChromeTheme) -> some View {
        HStack(spacing: 4) {
            if isDirectory {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(uiTheme.textTertiary)
                    .frame(width: 12)
            } else {
                Color.clear.frame(width: 12)
            }

            fileIconView(icon)
                .font(.system(size: 12))
                .foregroundColor(isDirectory ? uiTheme.primary : uiTheme.textSecondary)
                .frame(width: 16)

            Text(fileName)
                .font(.appCaption)
                .foregroundColor(uiTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            if let gitStatus = gitStatus {
                Text(gitStatus.displayLetter)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(gitStatusColor(gitStatus, isSelected: isSelected))
                    .frame(width: 16, alignment: .trailing)
                    .help(gitStatus.tooltip)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .padding(.leading, CGFloat(depth) * 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground(isSelected: isSelected, chrome: chrome))
        .contentShape(Rectangle())
        .onDrag {
            NSItemProvider(object: url.path as NSString)
        } preview: {
            FileTreeDragPreview(fileURL: url, isDirectory: isDirectory)
        }
        .contextMenu { contextMenuContent }
        .onTapGesture { handleTap() }
        .onHover { hovering in isHovering = hovering }
        .confirmationDialog(
            deleteConfirmationTitle,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(deleteConfirmationActionLabel, role: .destructive) { deleteItems() }
            Button(LumiPluginLocalization.string("Cancel", bundle: .module), role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
        .alert(LumiPluginLocalization.string("New File", bundle: .module), isPresented: $showNewFileSheet) {
            TextField(LumiPluginLocalization.string("File name", bundle: .module), text: $newItemName)
            Button(LumiPluginLocalization.string("Create", bundle: .module)) { createNewFile() }
            Button(LumiPluginLocalization.string("Cancel", bundle: .module), role: .cancel) {}
        } message: { Text(LumiPluginLocalization.string("Enter the name for the new file.", bundle: .module)) }
        .alert(LumiPluginLocalization.string("New Folder", bundle: .module), isPresented: $showNewFolderSheet) {
            TextField(LumiPluginLocalization.string("Folder name", bundle: .module), text: $newItemName)
            Button(LumiPluginLocalization.string("Create", bundle: .module)) { createNewFolder() }
            Button(LumiPluginLocalization.string("Cancel", bundle: .module), role: .cancel) {}
        } message: { Text(LumiPluginLocalization.string("Enter the name for the new folder.", bundle: .module)) }
        .alert(LumiPluginLocalization.string("Rename", bundle: .module), isPresented: $showRenameSheet) {
            TextField(LumiPluginLocalization.string("New name", bundle: .module), text: $newItemName)
            Button(LumiPluginLocalization.string("Rename", bundle: .module)) { renameItem() }
            Button(LumiPluginLocalization.string("Cancel", bundle: .module), role: .cancel) {}
        } message: { Text(LumiPluginLocalization.string("Enter the new name for this item.", bundle: .module)) }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        if !isBatchAction && isDirectory {
            Button {
                newItemName = ""
                showNewFileSheet = true
            } label: {
                Label(LumiPluginLocalization.string("New File", bundle: .module), systemImage: "doc.badge.plus")
            }
            Button {
                newItemName = ""
                showNewFolderSheet = true
            } label: {
                Label(LumiPluginLocalization.string("New Folder", bundle: .module), systemImage: "folder.badge.plus")
            }
            Divider()
        }

        if !isBatchAction {
            Button {
                newItemName = fileName
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { showRenameSheet = true }
            } label: {
                Label(LumiPluginLocalization.string("Rename", bundle: .module), systemImage: "pencil")
            }

            Divider()
        }

        Button { addToConversation() } label: {
            Label(addToConversationLabel, systemImage: "bubble.left.and.bubble.right")
        }
        if !isBatchAction {
            Button { openInFinder() } label: { Label(LumiPluginLocalization.string("Reveal in Finder", bundle: .module), systemImage: "finder") }
            Button { openInVSCode() } label: { Label(LumiPluginLocalization.string("Open in VS Code", bundle: .module), systemImage: "chevron.left.forwardslash.chevron.right") }
            Button { openInTerminal() } label: { Label(LumiPluginLocalization.string("Open in Terminal", bundle: .module), systemImage: "terminal") }
            Button { copyPath() } label: { Label(LumiPluginLocalization.string("Copy Path", bundle: .module), systemImage: "doc.on.doc") }
        }
        Divider()
        if !batchActionURLs.isEmpty {
            Button(role: .destructive) { showDeleteConfirmation = true } label: {
                Label(moveToTrashLabel, systemImage: "trash")
            }
        }
    }

    // MARK: - Event Handler

    private func handleTap() {
        selectionState.handleTap(
            url: url,
            isDirectory: isDirectory,
            modifiers: ModifierFlags.currentClick,
            onOpenFile: { onSelect(url) },
            onToggleExpand: {
                isExpanded.toggle()
                persistExpansionState()
                notifyExpansionChanged(isExpanded: isExpanded)
                if isExpanded && children.isEmpty {
                    loadChildren()
                }
            }
        )
    }

    private func handleRefreshTokenChange(_ newValue: Int) {
        guard newValue != lastRefreshToken else { return }
        lastRefreshToken = newValue
        
        // 全局刷新令牌变化时，检查自身是否在精准刷新范围内
        // 如果 changedDirectoryPaths 非空且命中，则 reload；否则跳过，让 Equatable 优化跳过未变化节点
        guard isDirectory, isExpanded else { return }
        
        if !changedDirectoryPaths.isEmpty {
            let ownPath = PathFormatter.normalizedFilePath(url)
            guard changedDirectoryPaths.contains(ownPath) else { return }
        }
        
        reloadChildren()
    }

    /// 精准刷新：仅当本节点目录命中协调器下发的变化集合时才重载子项，
    /// 避免文件系统事件触发整棵树无差别磁盘 I/O。
    private func handleTargetedRefresh() {
        guard isDirectory, isExpanded, !changedDirectoryPaths.isEmpty else { return }
        let ownPath = PathFormatter.normalizedFilePath(url)
        guard changedDirectoryPaths.contains(ownPath) else { return }
        reloadChildren()
    }

    // MARK: - View Helpers

    /// 当前节点的 Git 状态（从 snapshot 查询，文件查文件状态，目录查聚合状态）
    private var currentGitStatus: GitStatus? {
        guard EditorFileTreePanelPlugin.gitStatusEnabled else { return nil }
        guard !gitStatusSnapshot.isEmpty else { return nil }
        let path = gitRelativePath
        if isDirectory {
            return gitStatusSnapshot.aggregateStatusForDirectory(path)
        } else {
            return gitStatusSnapshot.statusForPath(path)
        }
    }

    /// Git 状态标记颜色
    private func gitStatusColor(
        _ status: GitStatus,
        isSelected: Bool
    ) -> Color {
        // 选中行时使用更亮的颜色保持对比度
        let baseColor: Color
        switch status {
        case .modified:
            baseColor = Color.orange
        case .added, .untracked:
            baseColor = Color.green
        case .deleted:
            baseColor = Color.red
        case .renamed:
            baseColor = Color.purple
        case .staged:
            baseColor = Color.orange.opacity(0.7)
        case .conflicted:
            baseColor = Color.red
        }
        return isSelected ? baseColor.opacity(0.9) : baseColor.opacity(0.7)
    }

    private var resolvedIcon: LumiFileIcon {
        let context = LumiFileIconContext(
            url: url,
            fileName: iconMetadata.fileName,
            fileExtension: iconMetadata.fileExtension,
            isDirectory: iconMetadata.isDirectory,
            isExpanded: isExpanded,
            isSwiftPackageDirectory: iconMetadata.isSwiftPackageDirectory,
            projectRootPath: projectRootPath
        )
        let activeContributor = editorContext.activeFileIconTheme
        if let icon = activeContributor?.icon(for: context) {
            return icon
        }
        if let icon = Self.defaultIconContributor.icon(for: context) {
            return icon
        }
        if iconMetadata.isDirectory, let icon = activeContributor?.defaultFolderIcon(isExpanded: isExpanded) {
            return icon
        }
        if !iconMetadata.isDirectory, let icon = activeContributor?.defaultFileIcon() {
            return icon
        }
        return iconMetadata.isDirectory
            ? Self.defaultIconContributor.defaultFolderIcon(isExpanded: isExpanded)
            : Self.defaultIconContributor.defaultFileIcon()
    }

    @ViewBuilder
    private func fileIconView(_ icon: LumiFileIcon) -> some View {
        switch icon {
        case .systemImage(let name):
            Image(systemName: name)
        case .assetImage(let name, let bundle):
            Image(name, bundle: bundle)
        }
    }

    private func rowBackground(isSelected: Bool, chrome: any LumiAppChromeTheme) -> Color {
        if isSelected {
            return isHovering ? chrome.sidebarSelectionColor().opacity(1.2) : chrome.sidebarSelectionColor()
        } else {
            return isHovering ? uiTheme.textPrimary.opacity(0.06) : Color.clear
        }
    }

    private var batchActionURLs: [URL] {
        let targets = selectionState.actionTargets(for: url)
        guard !projectRootPath.isEmpty else { return targets }
        let rootPath = PathFormatter.normalizedFilePath(
            URL(fileURLWithPath: projectRootPath)
        )
        return targets.filter {
            PathFormatter.normalizedFilePath($0) != rootPath
        }
    }

    private var isBatchAction: Bool {
        batchActionURLs.count > 1
    }

    private var addToConversationLabel: String {
        if isBatchAction {
            return String(
                format: LumiPluginLocalization.string("Add %lld Items to Conversation", bundle: .module),
                batchActionURLs.count
            )
        }
        return LumiPluginLocalization.string("Add to Conversation", bundle: .module)
    }

    private var moveToTrashLabel: String {
        if isBatchAction {
            return String(
                format: LumiPluginLocalization.string("Move %lld Items to Trash", bundle: .module),
                batchActionURLs.count
            )
        }
        return LumiPluginLocalization.string("Move to Trash", bundle: .module)
    }

    private var deleteConfirmationTitle: String {
        if isBatchAction {
            return String(
                format: LumiPluginLocalization.string("Are you sure you want to delete %lld items?", bundle: .module),
                batchActionURLs.count
            )
        }
        return String(
            format: LumiPluginLocalization.string("Are you sure you want to delete \"%@\"?", bundle: .module),
            fileName
        )
    }

    private var deleteConfirmationMessage: String {
        if isBatchAction {
            return String(
                format: LumiPluginLocalization.string("These %lld items will be moved to the Trash.", bundle: .module),
                batchActionURLs.count
            )
        }
        return LumiPluginLocalization.string("This item will be moved to the Trash.", bundle: .module)
    }

    private var deleteConfirmationActionLabel: String {
        moveToTrashLabel
    }
}

private struct FileTreeIconMetadata {
    public let fileName: String
    public let fileExtension: String
    public let isDirectory: Bool
    public let isSwiftPackageDirectory: Bool
}

// MARK: - Actions

extension NodeView {

    // MARK: - Expansion Persistence

    /// 当前节点相对于项目根目录的路径，保留开头的 "/" 以兼容已持久化的展开状态。
    private var relativePath: String {
        PathFormatter.expansionPath(for: url, projectRootPath: projectRootPath)
    }

    /// 将当前展开/折叠状态持久化到 store
    private func persistExpansionState() {
        guard !projectRootPath.isEmpty else { return }
        let store = FileTreeSettings.shared
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
        loadChildrenTask?.cancel()
        isLoadingChildren = true
        loadChildrenTask = Task { @MainActor in
            do {
                let sorted = try await Task.detached(priority: .userInitiated) {
                    try FileTreeFacade.loadContents(of: currentURL)
                }.value
                guard !Task.isCancelled else { return }
                children = sorted
                hasLoadedChildren = true
                isLoadingChildren = false
            } catch {
                guard !Task.isCancelled else { return }
                children = []
                hasLoadedChildren = true
                isLoadingChildren = false
            }
        }
    }

    private func reloadChildren() { loadChildren() }

    private func createNewFile() {
        if FileTreeFacade.createFile(in: url, name: newItemName) != nil {
            reloadChildren()
            notifyTreeMutation()
        }
    }

    private func createNewFolder() {
        if FileTreeFacade.createFolder(in: url, name: newItemName) != nil {
            reloadChildren()
            notifyTreeMutation()
        }
    }

    private func renameItem() {
        if let newURL = FileTreeFacade.renameItem(at: url, newName: newItemName) {
            onSelect(newURL)
            notifyTreeMutation()
        }
    }

    private func deleteItems() {
        guard !batchActionURLs.isEmpty else { return }
        if FileTreeFacade.trashItems(at: batchActionURLs) > 0 {
            selectionState.clearSelection()
            notifyTreeMutation()
        }
    }

    private func notifyTreeMutation() {
        onTreeMutation?()
    }

    private func openInFinder() {
        FileTreeFacade.openInFinder(url)
    }

    private func openInVSCode() {
        FileTreeFacade.openInVSCode(url)
    }

    private func openInTerminal() {
        FileTreeFacade.openInTerminal(url)
    }

    private func copyPath() {
        FileTreeFacade.copyPath(url)
    }

    /// 与拖入输入区相同：图片走附件，其它文件插入路径
    private func addToConversation() {
        editorContext.addToConversation(fileURLs: batchActionURLs, windowId: windowId)
    }
}

// MARK: - Preview

#Preview {
    let testURL = URL(fileURLWithPath: NSHomeDirectory())
    return NodeView(
        url: testURL,
        depth: 0,
        onSelect: { _ in }
    )
    .environmentObject(SelectionState())
    .frame(width: 250, height: 400)
}
