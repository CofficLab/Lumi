import CodeEditor
import MagicKit
import SwiftUI

/// 文件预览视图的撤销/重做状态管理
/// UndoManager 的 registerUndo(withTarget:) 要求 target 是 class 类型，
/// 所以需要一个独立的引用类型来持有可变内容。
@MainActor
final class FilePreviewUndoState: ObservableObject {
    /// 当前文件内容
    @Published var content: String = ""

    /// 撤销管理器
    let undoManager = UndoManager()

    /// 删除指定范围的文本（用于剪切），并注册撤销操作
    func deleteRange(_ range: Range<String.Index>) {
        let deletedText = String(content[range])
        let offset = content.distance(from: content.startIndex, to: range.lowerBound)

        content.removeSubrange(range)

        // 注册撤销：恢复被删除的文本
        undoManager.registerUndo(withTarget: self) { target in
            target.insertText(deletedText, at: offset, isUndo: true)
        }
        undoManager.setActionName(String(localized: "Cut", table: "FilePreview"))
    }

    /// 在指定位置插入文本（用于撤销剪切），并注册重做操作
    private func insertText(_ text: String, at offset: Int, isUndo: Bool) {
        let index = content.index(content.startIndex, offsetBy: min(offset, content.count))

        content.insert(contentsOf: text, at: index)

        // 注册反向操作
        let newOffset = offset
        let length = text.count
        undoManager.registerUndo(withTarget: self) { target in
            target.removeRange(offset: newOffset, length: length)
        }
        undoManager.setActionName(
            isUndo
                ? String(localized: "Restore Cut", table: "FilePreview")
                : String(localized: "Cut", table: "FilePreview")
        )
    }

    /// 移除指定范围的文本（用于重做剪切）
    private func removeRange(offset: Int, length: Int) {
        let startIndex = content.index(content.startIndex, offsetBy: min(offset, content.count))
        let endIndex = content.index(
            startIndex,
            offsetBy: min(length, content.distance(from: startIndex, to: content.endIndex))
        )
        let removedText = String(content[startIndex..<endIndex])

        content.removeSubrange(startIndex..<endIndex)

        let insertOffset = offset
        undoManager.registerUndo(withTarget: self) { target in
            target.insertText(removedText, at: insertOffset, isUndo: false)
        }
        undoManager.setActionName(String(localized: "Cut", table: "FilePreview"))
    }

    /// 执行撤销
    func undo() {
        guard undoManager.canUndo else { return }
        undoManager.undo()
    }

    /// 执行重做
    func redo() {
        guard undoManager.canRedo else { return }
        undoManager.redo()
    }

    /// 清除所有撤销/重做记录（切换文件时调用）
    func clearHistory() {
        undoManager.removeAllActions()
    }
}

private struct BreadcrumbPopoverRow: Identifiable {
    let url: URL
    let isDirectory: Bool
    let level: Int

    var id: String { url.standardizedFileURL.path }
    var name: String { url.lastPathComponent }
}

private struct BreadcrumbPopoverRowsView: View {
    let rows: [BreadcrumbPopoverRow]
    let activeItemPath: String
    let selectedFilePath: String?
    let isDirectoryExpanded: (URL) -> Bool
    let onToggleDirectory: (URL) -> Void
    let onSelectFile: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(rows, id: \BreadcrumbPopoverRow.id) { (row: BreadcrumbPopoverRow) in
                let isActiveItem = row.url.standardizedFileURL.path == activeItemPath
                let isSelectedFile = row.url.standardizedFileURL.path == selectedFilePath

                HStack(spacing: 6) {
                    Color.clear
                        .frame(width: CGFloat(row.level) * 14)

                    if row.isDirectory {
                        Button {
                            onToggleDirectory(row.url)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isDirectoryExpanded(row.url) ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                                    .frame(width: 12)
                                Image(systemName: "folder")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppUI.Color.semantic.primary)
                                Text(row.name)
                                    .font(.system(size: 12, weight: isActiveItem ? .semibold : .regular))
                                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            onSelectFile(row.url)
                        } label: {
                            HStack(spacing: 6) {
                                Color.clear.frame(width: 12)
                                Image(systemName: "doc")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                                Text(row.name)
                                    .font(.system(size: 12, weight: isSelectedFile ? .semibold : .regular))
                                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill((isActiveItem || isSelectedFile) ? AppUI.Color.semantic.primary.opacity(0.12) : Color.clear)
                )
            }
        }
    }
}

/// 文件预览视图
struct FilePreviewView: View {
    private struct BreadcrumbItem: Identifiable {
        let index: Int
        let name: String
        let url: URL
        let isDirectory: Bool

        var id: Int { index }
    }

    private struct BreadcrumbSiblingItem: Identifiable {
        let url: URL
        let isDirectory: Bool

        var id: String { url.path }
        var name: String { url.lastPathComponent }
    }

    @EnvironmentObject var ProjectVM: ProjectVM

    /// 主题更新触发器
    @State private var themeUpdateTrigger: UUID = UUID()

    /// 当前文件内容（本地加载）
    @State private var fileContent: String = ""
    @State private var persistedContent: String = ""
    @State private var selectedTheme: CodeEditor.ThemeName = .default
    @State private var canPreviewCurrentFile: Bool = false
    @State private var isReadOnlyPreview: Bool = false
    @State private var isTruncatedPreview: Bool = false

    /// 当前文本选区
    @State private var textSelection: Range<String.Index>? = nil

    /// 选区菜单可见性
    @State private var showSelectionMenu: Bool = false

    /// 选区菜单定位（相对于内容区域的偏移）
    @State private var selectionMenuPosition: CGPoint = .zero

    /// 用于隐藏菜单的延迟任务
    @State private var hideMenuTask: Task<Void, Never>? = nil

    /// 当前打开的面包屑弹出层索引
    @State private var activeBreadcrumbPopoverIndex: Int? = nil

    /// 面包屑弹出层中已展开的目录路径
    @State private var expandedBreadcrumbDirectoryPaths: Set<String> = []

    /// 撤销/重做状态管理
    @StateObject private var undoState = FilePreviewUndoState()

    private static let themeStorageKey = "FilePreview.SelectedCodeEditorTheme"
    private static let textProbeBytes = 8192
    private static let readOnlyThresholdBytes: Int64 = 512 * 1024
    private static let truncationThresholdBytes: Int64 = 2 * 1024 * 1024
    private static let truncationReadBytes = 256 * 1024

    // MARK: - Menu Layout Constants

    private static let menuHeight: CGFloat = 30
    private static let menuVerticalGap: CGFloat = 6
    private static let menuCornerRadius: CGFloat = 8

    /// 获取当前选中文本
    private var selectedText: String? {
        guard let sel = textSelection else { return nil }
        guard !sel.isEmpty else { return nil }
        return String(fileContent[sel])
    }

    /// 获取当前文件扩展名
    private var fileExtension: String {
        guard let url = ProjectVM.selectedFileURL else { return "" }
        return url.pathExtension.lowercased()
    }

    /// 获取当前文件完整名称
    private var fileName: String {
        guard let url = ProjectVM.selectedFileURL else { return "" }
        return url.lastPathComponent
    }

    var body: some View {
        VStack(spacing: 0) {
            if ProjectVM.isFileSelected {
                breadcrumbSection
            }

            GlassDivider()

            if ProjectVM.isFileSelected {
                if canPreviewCurrentFile {
                    filePreviewContent
                } else {
                    FilePreviewUnsupportedView(fileName: "\(ProjectVM.selectedFileURL?.lastPathComponent ?? "")")
                }
            } else {
                FilePreviewEmptyStateView()
            }
        }
        .onChange(of: ProjectVM.selectedFileURL) { _, newURL in
            loadFileContent(from: newURL)
        }
        .onAppear {
            restoreThemeSelection()
            loadFileContent(from: ProjectVM.selectedFileURL)
        }
        .onFilePreviewThemeChanged { newTheme in
            selectedTheme = newTheme
            themeUpdateTrigger = UUID()
        }
        .onChange(of: undoState.content) { _, newContent in
            if fileContent != newContent {
                fileContent = newContent
            }
        }
    }

    // MARK: - Breadcrumb Section

    /// 面包屑路径段列表（相对于项目根，若无项目则全路径）
    private var breadcrumbItems: [BreadcrumbItem] {
        guard let fileURL = ProjectVM.selectedFileURL else { return [] }

        let fullPath = fileURL.standardizedFileURL.path
        if let projectPath = ProjectVM.currentProject?.path,
           fullPath.hasPrefix(projectPath + "/") {
            let relative = String(fullPath.dropFirst(projectPath.count + 1))
            let segments = relative.split(separator: "/").map(String.init)
            var runningPath = projectPath

            return segments.enumerated().map { index, segment in
                runningPath += "/" + segment
                let segmentURL = URL(fileURLWithPath: runningPath)
                let isDirectory = (try? segmentURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return BreadcrumbItem(index: index, name: segment, url: segmentURL, isDirectory: isDirectory)
            }
        }

        let segments = fullPath.split(separator: "/").map(String.init)
        var runningPath = ""

        return segments.enumerated().map { index, segment in
            runningPath += "/" + segment
            let segmentURL = URL(fileURLWithPath: runningPath)
            let isDirectory = (try? segmentURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return BreadcrumbItem(index: index, name: segment, url: segmentURL, isDirectory: isDirectory)
        }
    }

    private func childItems(in directoryURL: URL) -> [BreadcrumbSiblingItem] {
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
        } catch {
            return []
        }

        return urls.map { url in
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return BreadcrumbSiblingItem(url: url, isDirectory: isDirectory)
        }
        .sorted { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    private func isDirectoryExpanded(_ url: URL) -> Bool {
        expandedBreadcrumbDirectoryPaths.contains(url.standardizedFileURL.path)
    }

    private func toggleDirectoryExpansion(_ url: URL) {
        let path = url.standardizedFileURL.path
        if expandedBreadcrumbDirectoryPaths.contains(path) {
            expandedBreadcrumbDirectoryPaths.remove(path)
        } else {
            expandedBreadcrumbDirectoryPaths.insert(path)
        }
    }

    private func openBreadcrumbPopover(for item: BreadcrumbItem) {
        let rootURL = item.url.deletingLastPathComponent().standardizedFileURL
        let startURL = (item.isDirectory ? item.url : item.url.deletingLastPathComponent()).standardizedFileURL
        var expanded: Set<String> = []
        var cursor = startURL

        while cursor.path != rootURL.path {
            expanded.insert(cursor.path)
            let parent = cursor.deletingLastPathComponent().standardizedFileURL
            if parent.path == cursor.path { break }
            cursor = parent
        }

        expandedBreadcrumbDirectoryPaths = expanded
        activeBreadcrumbPopoverIndex = item.index
    }

    private func flattenedBreadcrumbRows(
        from items: [BreadcrumbSiblingItem],
        level: Int = 0
    ) -> [BreadcrumbPopoverRow] {
        var rows: [BreadcrumbPopoverRow] = []

        for item in items {
            rows.append(BreadcrumbPopoverRow(url: item.url, isDirectory: item.isDirectory, level: level))
            if item.isDirectory, isDirectoryExpanded(item.url) {
                let children = childItems(in: item.url)
                rows.append(contentsOf: flattenedBreadcrumbRows(from: children, level: level + 1))
            }
        }

        return rows
    }

    private func breadcrumbPopoverContent(for item: BreadcrumbItem) -> some View {
        let siblings = childItems(in: item.url.deletingLastPathComponent())
        let rows = flattenedBreadcrumbRows(from: siblings)
        let selectedFilePath = ProjectVM.selectedFileURL?.standardizedFileURL.path
        let activeItemPath = item.url.standardizedFileURL.path

        return ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                if rows.isEmpty {
                    Text(String(localized: "No Items", table: "FilePreview"))
                        .font(.system(size: 12))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                } else {
                    BreadcrumbPopoverRowsView(
                        rows: rows,
                        activeItemPath: activeItemPath,
                        selectedFilePath: selectedFilePath,
                        isDirectoryExpanded: { url in isDirectoryExpanded(url) },
                        onToggleDirectory: { url in toggleDirectoryExpansion(url) },
                        onSelectFile: { url in
                            ProjectVM.selectFile(at: url)
                            activeBreadcrumbPopoverIndex = nil
                        }
                    )
                }
            }
            .padding(6)
        }
        .frame(width: 460, height: 280)
    }

    private var breadcrumbSection: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(breadcrumbItems) { item in
                        let isLast = item.index == breadcrumbItems.count - 1

                        if item.index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppUI.Color.semantic.textTertiary)
                                .padding(.horizontal, 1)
                        }

                        Button {
                            openBreadcrumbPopover(for: item)
                        } label: {
                            Text(item.name)
                                .font(.system(size: 11, weight: isLast ? .semibold : .regular))
                                .foregroundColor(
                                    isLast
                                        ? AppUI.Color.semantic.textPrimary
                                        : AppUI.Color.semantic.textSecondary
                                )
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .popover(
                            isPresented: Binding(
                                get: { activeBreadcrumbPopoverIndex == item.index },
                                set: { isPresented in
                                    if !isPresented, activeBreadcrumbPopoverIndex == item.index {
                                        activeBreadcrumbPopoverIndex = nil
                                    }
                                }
                            ),
                            arrowEdge: .bottom
                        ) {
                            breadcrumbPopoverContent(for: item)
                        }
                        .id(item.index)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .onAppear {
                if let last = breadcrumbItems.indices.last {
                    proxy.scrollTo(last, anchor: .trailing)
                }
            }
            .onChange(of: ProjectVM.selectedFileURL) { _, _ in
                if let last = breadcrumbItems.indices.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last, anchor: .trailing)
                    }
                }
                activeBreadcrumbPopoverIndex = nil
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: AppConfig.headerHeight)
    }

    // MARK: - File Preview Content

    private var filePreviewContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            fileInfoSection

            ZStack(alignment: .topLeading) {
                fileContentSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if showSelectionMenu, selectedText != nil {
                    TextSelectionMenu(
                        selectedText: selectedText ?? "",
                        isEditable: !isReadOnlyPreview,
                        onCut: performCut,
                        onCopy: performCopy,
                        onAddToChat: performAddToChat
                    )
                    .position(x: selectionMenuPosition.x, y: selectionMenuPosition.y)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                    .animation(.easeOut(duration: 0.15), value: showSelectionMenu)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onKeyPress(keys: [.init("z")], phases: .down) { press in
            if press.modifiers.contains(.command) && !press.modifiers.contains(.shift) {
                undoState.undo()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(keys: [.init("z")], phases: .down) { press in
            if press.modifiers.contains(.command) && press.modifiers.contains(.shift) {
                undoState.redo()
                return .handled
            }
            return .ignored
        }
    }

    private var fileInfoSection: some View {
        Group {
            if isTruncatedPreview || isReadOnlyPreview {
                VStack(alignment: .leading, spacing: 4) {
                    if isTruncatedPreview {
                        Text(String(localized: "Preview Truncated for Large File", table: "FilePreview"))
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                            .lineLimit(2)
                    } else if isReadOnlyPreview {
                        Text(String(localized: "Large File Read-Only Preview", table: "FilePreview"))
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    private var fileContentSection: some View {
        FileContentSectionView(
            content: $fileContent,
            fileExtension: fileExtension,
            fileName: fileName,
            theme: selectedTheme,
            isEditable: !isReadOnlyPreview && canPreviewCurrentFile,
            forcePlainText: isReadOnlyPreview,
            selection: $textSelection
        )
        .onChange(of: textSelection) { _, newSelection in
            handleSelectionChange(newSelection)
        }
    }

    // MARK: - Selection Handling

    private func handleSelectionChange(_ newSelection: Range<String.Index>?) {
        hideMenuTask?.cancel()
        hideMenuTask = nil

        guard let sel = newSelection, !sel.isEmpty else {
            ProjectVM.updateCodeSelection(nil)

            hideMenuTask = Task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.12)) {
                        showSelectionMenu = false
                    }
                }
            }
            return
        }

        syncCodeSelectionRange(sel)
        updateSelectionMenuPosition(for: sel)

        withAnimation(.easeOut(duration: 0.15)) {
            showSelectionMenu = true
        }
    }

    /// 将文本选区转换为行列号信息并同步到 ProjectVM
    private func syncCodeSelectionRange(_ sel: Range<String.Index>) {
        guard let fileURL = ProjectVM.selectedFileURL else { return }

        let filePath = relativeFilePath(for: fileURL)

        let startInfo = lineAndColumn(at: sel.lowerBound)
        let endInfo = lineAndColumn(at: sel.upperBound)

        let range = CodeSelectionRange(
            filePath: filePath,
            startLine: startInfo.line,
            startColumn: startInfo.column,
            endLine: endInfo.line,
            endColumn: endInfo.column
        )

        ProjectVM.updateCodeSelection(range)
    }

    /// 计算文件路径相对于项目根目录的路径
    private func relativeFilePath(for url: URL) -> String {
        guard let projectPath = ProjectVM.currentProject?.path else {
            return url.lastPathComponent
        }
        let absolutePath = url.path
        guard absolutePath.hasPrefix(projectPath) else {
            return url.lastPathComponent
        }
        let startIndex = absolutePath.index(absolutePath.startIndex, offsetBy: projectPath.count)
        var relative = String(absolutePath[startIndex...])
        if relative.hasPrefix("/") {
            relative = String(relative.dropFirst())
        }
        return relative
    }

    /// 计算指定 String.Index 对应的行号和列号（均从 1 开始）
    private func lineAndColumn(at index: String.Index) -> (line: Int, column: Int) {
        let textBefore = fileContent[fileContent.startIndex..<index]
        let line = textBefore.filter { $0 == "\n" }.count + 1

        let column: Int
        if let lastNL = textBefore.lastIndex(of: "\n") {
            column = textBefore.distance(from: textBefore.index(after: lastNL), to: textBefore.endIndex) + 1
        } else {
            column = textBefore.count + 1
        }

        return (line, column)
    }

    private func updateSelectionMenuPosition(for sel: Range<String.Index>) {
        let textBeforeSelection = String(fileContent[fileContent.startIndex..<sel.lowerBound])
        let lineCount = textBeforeSelection.filter { $0 == "\n" }.count
        let lineHeight: CGFloat = 18
        let topPadding: CGFloat = 12

        let lastNewline = textBeforeSelection.lastIndex(of: "\n")
        let linePrefix = lastNewline == nil
            ? textBeforeSelection
            : String(textBeforeSelection[textBeforeSelection.index(after: lastNewline!)...])
        let charWidth: CGFloat = 7.2
        let leftPadding: CGFloat = 12

        let selectionTopY = topPadding + CGFloat(lineCount) * lineHeight
        let menuCenterY = selectionTopY - Self.menuVerticalGap - (Self.menuHeight / 2)

        let menuWidth: CGFloat = 130
        let menuCenterX = leftPadding + CGFloat(linePrefix.count) * charWidth + (menuWidth / 2)

        selectionMenuPosition = CGPoint(x: menuCenterX, y: menuCenterY)
    }

    // MARK: - Edit Actions

    private func performCopy() {
        guard let text = selectedText else { return }

        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif

        dismissSelectionMenu()
    }

    private func performCut() {
        guard selectedText != nil, !isReadOnlyPreview else { return }
        guard let sel = textSelection else { return }

        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selectedText ?? "", forType: .string)
        #else
        UIPasteboard.general.string = selectedText
        #endif

        undoState.content = fileContent
        undoState.deleteRange(sel)

        fileContent = undoState.content
        textSelection = nil

        dismissSelectionMenu()
    }

    /// 将当前选区信息添加到聊天输入框
    private func performAddToChat() {
        guard let range = ProjectVM.codeSelectionRange else { return }

        // 格式化选区位置信息，例如：`LumiApp/Core/Models/CodeSelectionRange.swift:10:1-15:20`
        let locationText = "\(range.filePath):\(range.startLine):\(range.startColumn)-\(range.endLine):\(range.endColumn)"

        NotificationCenter.postAddToChat(text: locationText)

        dismissSelectionMenu()
    }

    private func dismissSelectionMenu() {
        hideMenuTask?.cancel()
        hideMenuTask = nil
        withAnimation(.easeOut(duration: 0.12)) {
            showSelectionMenu = false
        }
    }

    // MARK: - File Loading

    private func loadFileContent(from url: URL?) {
        guard let url = url else {
            fileContent = ""
            persistedContent = ""
            canPreviewCurrentFile = false
            isReadOnlyPreview = false
            isTruncatedPreview = false
            textSelection = nil
            showSelectionMenu = false
            undoState.content = ""
            undoState.clearHistory()
            return
        }

        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDirectory {
            fileContent = ""
            persistedContent = ""
            canPreviewCurrentFile = false
            isReadOnlyPreview = false
            isTruncatedPreview = false
            textSelection = nil
            showSelectionMenu = false
            undoState.content = ""
            undoState.clearHistory()
            return
        }

        let selectedURL = url
        Task {
            do {
                let fileSize = Int64((try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                guard try isLikelyTextFile(url: url) else {
                    await MainActor.run {
                        guard ProjectVM.selectedFileURL == selectedURL else { return }
                        self.fileContent = ""
                        self.persistedContent = ""
                        self.canPreviewCurrentFile = false
                        self.isReadOnlyPreview = false
                        self.isTruncatedPreview = false
                        self.textSelection = nil
                        self.showSelectionMenu = false
                        self.undoState.content = ""
                        self.undoState.clearHistory()
                    }
                    return
                }

                let shouldTruncate = fileSize > Self.truncationThresholdBytes
                let shouldReadOnly = fileSize > Self.readOnlyThresholdBytes
                let content: String
                if shouldTruncate {
                    content = try readTruncatedContent(from: url, maxBytes: Self.truncationReadBytes)
                } else {
                    var detectedEncoding = String.Encoding.utf8
                    content = try String(contentsOf: url, usedEncoding: &detectedEncoding)
                }

                await MainActor.run {
                    guard ProjectVM.selectedFileURL == selectedURL else { return }
                    self.fileContent = content
                    self.persistedContent = content
                    self.canPreviewCurrentFile = true
                    self.isReadOnlyPreview = shouldReadOnly
                    self.isTruncatedPreview = shouldTruncate
                    self.textSelection = nil
                    self.showSelectionMenu = false
                    self.undoState.content = content
                    self.undoState.clearHistory()
                }
            } catch {
                await MainActor.run {
                    guard ProjectVM.selectedFileURL == selectedURL else { return }
                    self.fileContent = "无法加载文件内容：\(error.localizedDescription)"
                    self.persistedContent = ""
                    self.canPreviewCurrentFile = false
                    self.isReadOnlyPreview = false
                    self.isTruncatedPreview = false
                    self.textSelection = nil
                    self.showSelectionMenu = false
                }
            }
        }
    }

    // MARK: - Theme Management

    private func restoreThemeSelection() {
        guard let storedRawValue = FilePreviewThemeStateStore.loadString(forKey: Self.themeStorageKey) else { return }
        if let matchedTheme = CodeEditor.availableThemes.first(where: { $0.rawValue == storedRawValue }) {
            selectedTheme = matchedTheme
        }
    }

    private func persistThemeSelection(_ theme: CodeEditor.ThemeName) {
        FilePreviewThemeStateStore.saveString(theme.rawValue, forKey: Self.themeStorageKey)
    }

    // MARK: - File Reading Helpers

    private func readTruncatedContent(from url: URL, maxBytes: Int) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let data = try handle.read(upToCount: maxBytes) ?? Data()
        let preview = String(decoding: data, as: UTF8.self)
        let suffix = "\n\n… " + String(localized: "File too large. Preview is truncated.", table: "FilePreview")
        return preview + suffix
    }

    private func isLikelyTextFile(url: URL) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let sample = try handle.read(upToCount: Self.textProbeBytes) ?? Data()
        if sample.isEmpty { return true }

        if sample.contains(0) {
            return false
        }

        var controlByteCount = 0
        for byte in sample {
            if byte == 0x09 || byte == 0x0A || byte == 0x0D {
                continue
            }
            if byte < 0x20 {
                controlByteCount += 1
            }
        }

        let ratio = Double(controlByteCount) / Double(sample.count)
        return ratio < 0.05
    }
}

// MARK: - Preview

#Preview {
    FilePreviewView()
        .inRootView()
}
