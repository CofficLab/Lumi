import SwiftUI

/// 文件树节点视图 - 完全独立实现，无外部依赖
struct FileNodeView: View {
    /// 日志前缀的表情符号（文件树节点）
    nonisolated static let emoji = "📁"

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

    /// 删除确认对话框
    @State private var showDeleteConfirmation: Bool = false

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

// MARK: - View Helpers

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
    /// 处理点击事件
    private func handleTap() {
        if isDirectory {
            isExpanded.toggle()
            if isExpanded && children.isEmpty {
                loadChildren()
            }
        }
        onSelect(url)
    }

    /// 加载当前目录下的子节点，并按"目录在前"的规则排序
    private func loadChildren() {
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
                print("📁 loadChildren error: \(error.localizedDescription)")
            }
        }
    }

    /// 在 Finder 中显示文件/文件夹
    private func openInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// 在 VS Code 中打开文件/文件夹
    private func openInVSCode() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["code", url.path]
        
        do {
            try process.run()
            process.terminationHandler = { _ in
                print("📁 VS Code opened: \(url.path)")
            }
        } catch {
            print("📁 Failed to open VS Code: \(error.localizedDescription)")
            // 备选方案：使用 NSWorkspace 打开
            NSWorkspace.shared.open(url)
        }
    }

    /// 在终端中打开（打开目录或文件所在目录）
    private func openInTerminal() {
        let targetPath = isDirectory ? url.path : url.deletingLastPathComponent().path
        
        // 使用 AppleScript 打开 Terminal 并 cd 到目标目录
        let script = """
        tell application "Terminal"
            activate
            if (count of windows) > 0 then
                do script "cd '\(targetPath)'" in front window
            else
                do script "cd '\(targetPath)'"
            end if
        end tell
        """
        
        if let scriptObject = NSAppleScript(source: script) {
            var errorDict: NSDictionary?
            scriptObject.executeAndReturnError(&errorDict)
            if let error = errorDict {
                print("📁 AppleScript error: \(error)")
                // 备选方案：直接打开 Terminal.app
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
            }
        }
    }

    /// 删除文件/文件夹（移到废纸篓）
    private func deleteItem() {
        do {
            // 移动到废纸篓
            var resultURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
            print("📁 Moved to trash: \(url.path)")
        } catch {
            print("📁 Failed to move to trash: \(error.localizedDescription)")
        }
    }
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