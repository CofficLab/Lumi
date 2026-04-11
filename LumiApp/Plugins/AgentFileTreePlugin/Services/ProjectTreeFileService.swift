import Foundation
import SwiftUI
import MagicKit
import AppKit

/// 项目文件树文件服务
/// 负责处理文件相关的无状态逻辑：图标、名称、过滤、排序等
enum ProjectTreeFileService {
    /// 过滤并排序目录内容
    /// - Parameter urls: 目录下的 URL 列表
    /// - Returns: 过滤并排序后的 URL 列表（文件夹在前）
    static func filterAndSortContents(_ urls: [URL]) -> [URL] {
        // 过滤 .DS_Store 和 .git
        let filtered = urls.filter { url in
            let name = url.lastPathComponent
            return name != ".DS_Store" && name != ".git"
        }

        // 排序：文件夹在前
        let sorted = filtered.sorted { a, b in
            let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if aIsDir == bIsDir {
                return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
            }
            return aIsDir
        }

        return sorted
    }

    /// 获取文件图标
    /// - Parameter url: 文件 URL
    /// - Returns: 图标 SF Symbol 名称
    static func getFileIcon(for url: URL) -> String {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

        if isDirectory {
            return "folder.fill"
        }

        let ext = url.pathExtension.lowercased()

        switch ext {
        // 源代码文件
        case "swift":
            return "swift"
        case "m", "mm", "h":
            return "c.circle"

        // 配置文件
        case "json":
            return "curlybraces"
        case "yaml", "yml":
            return "list.bullet.indent"
        case "xml":
            return "chevron.left.forwardslash.chevron.right"
        case "plist":
            return "gearshape"
        case "xcworkspacedata":
            return "square.stack.3d.up"
        case "xcodeproj":
            return "hammer"

        // 图片资源
        case "png", "jpg", "jpeg", "gif", "webp", "svg", "icns", "ico":
            return "photo"
        case "pdf":
            return "doc.richtext"

        // 文档
        case "md", "markdown":
            return "doc.text"
        case "txt":
            return "doc.plaintext"
        case "rtf":
            return "doc.richtext"

        // 其他
        case "sh":
            return "terminal"
        case "gitignore":
            return "arrow.triangle.branch"

        default:
            return "doc"
        }
    }

    /// 获取文件显示名称
    /// - Parameter url: 文件 URL
    /// - Returns: 显示名称
    static func getFileName(for url: URL) -> String {
        url.lastPathComponent
    }

    /// 格式化文件修改日期
    /// - Parameter date: 日期
    /// - Returns: 格式化后的字符串
    static func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// 获取文件修改日期
    /// - Parameter url: 文件 URL
    /// - Returns: 修改日期
    static func getModificationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// 检查文件是否应该显示修改日期
    /// - Parameter url: 文件 URL
    /// - Returns: 是否显示
    static func shouldShowModificationDate(for url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        // 仅对常见文档类型显示修改日期
        let documentExtensions = ["swift", "m", "h", "md", "txt", "json", "xml", "yaml", "yml"]
        return documentExtensions.contains(ext)
    }

    /// 在终端中打开指定路径
    /// - Parameter url: 文件或目录 URL
    static func openInTerminal(_ url: URL) {
        let targetPath: String
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        
        if isDirectory {
            targetPath = url.path
        } else {
            targetPath = url.deletingLastPathComponent().path
        }

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
            if errorDict != nil {
                // 备选方案：直接打开 Terminal.app
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
            }
        }
    }

    /// 在 VS Code 中打开文件或文件夹
    /// - Parameter url: 文件或文件夹 URL
    static func openInVSCode(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["code", url.path]

        do {
            try process.run()
        } catch {
            // 备选方案：使用 NSWorkspace 打开
            NSWorkspace.shared.open(url)
        }
    }

    /// 复制文件绝对路径到剪贴板
    /// - Parameter url: 文件 URL
    static func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    /// 复制文件相对路径到剪贴板
    /// - Parameters:
    ///   - url: 文件 URL
    ///   - projectPath: 项目根路径
    static func copyRelativePath(_ url: URL, projectPath: String) {
        guard !projectPath.isEmpty else { return }
        let relativePath = url.path.replacingOccurrences(of: projectPath + "/", with: "")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(relativePath, forType: .string)
    }

    // MARK: - 文件系统查询

    /// 判断 URL 是否为目录
    /// - Parameter url: 文件或目录 URL
    /// - Returns: 是否为目录
    static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    /// 读取目录内容（过滤并排序后返回）
    ///
    /// 使用 `skipsSubdirectoryDescendants` 避免递归遍历子目录，
    /// 同时利用预取的 `isDirectoryKey` 资源值做排序，减少额外 I/O。
    /// - Parameter url: 目录 URL
    /// - Returns: 过滤并排序后的子项 URL 列表
    /// - Throws: 文件系统读取错误
    static func loadContents(of url: URL) throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsSubdirectoryDescendants
        )
        return filterAndSortContents(contents)
    }

    // MARK: - 文件操作

    /// 在指定目录下创建新文件
    /// - Parameters:
    ///   - parentURL: 父目录 URL
    ///   - name: 新文件名
    /// - Returns: 创建成功返回新文件 URL，失败返回 nil
    @discardableResult
    static func createFile(in parentURL: URL, name: String) -> URL? {
        guard !name.isEmpty else { return nil }
        let fileURL = parentURL.appendingPathComponent(name)
        let success = FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        return success ? fileURL : nil
    }

    /// 在指定目录下创建新文件夹
    /// - Parameters:
    ///   - parentURL: 父目录 URL
    ///   - name: 新文件夹名
    /// - Returns: 创建成功返回新文件夹 URL，失败返回 nil
    @discardableResult
    static func createFolder(in parentURL: URL, name: String) -> URL? {
        guard !name.isEmpty else { return nil }
        let folderURL = parentURL.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
            return folderURL
        } catch {
            return nil
        }
    }

    /// 重命名文件或文件夹
    /// - Parameters:
    ///   - url: 原始 URL
    ///   - newName: 新名称
    /// - Returns: 重命名成功返回新 URL，失败返回 nil
    @discardableResult
    static func renameItem(at url: URL, newName: String) -> URL? {
        guard !newName.isEmpty else { return nil }
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: url, to: newURL)
            return newURL
        } catch {
            return nil
        }
    }

    /// 将文件或文件夹移入废纸篓
    /// - Parameter url: 要删除的 URL
    /// - Returns: 是否成功
    @discardableResult
    static func trashItem(at url: URL) -> Bool {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return true
        } catch {
            return false
        }
    }

    // MARK: - 外部应用

    /// 在 Finder 中显示文件
    /// - Parameter url: 文件或目录 URL
    static func openInFinder(_ url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
}