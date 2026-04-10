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
}