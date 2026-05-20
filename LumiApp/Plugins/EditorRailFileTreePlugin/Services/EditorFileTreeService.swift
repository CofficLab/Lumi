import Foundation
import SwiftUI
import AppKit
import FileTreeKit

/// Editor Rail 文件树文件服务
/// 负责处理文件相关的无状态逻辑：图标、名称、过滤、排序等
///
/// 作为 FileTreeKit.FileTreeService 的薄包装层，
/// 保留插件特有的方法（openInTerminal、openInVSCode 等 UI 操作）。
enum EditorFileTreeService {
    // MARK: - 委托给 FileTreeKit

    /// 过滤并排序目录内容
    /// - Parameter urls: 目录下的 URL 列表
    /// - Returns: 过滤并排序后的 URL 列表（文件夹在前）
    static func filterAndSortContents(_ urls: [URL]) -> [URL] {
        FileTreeService.filterAndSortContents(urls)
    }

    /// 获取文件图标
    /// - Parameter url: 文件 URL
    /// - Returns: 图标 SF Symbol 名称
    static func getFileIcon(for url: URL) -> String {
        FileTreeService.iconSFSymbol(for: url)
    }

    /// 获取非目录文件图标，避免文件树行在 SwiftUI body 求值时反复查询文件系统资源值。
    /// - Parameter fileExtension: 文件扩展名
    /// - Returns: 图标 SF Symbol 名称
    static func getFileIcon(fileExtension: String) -> String {
        FileTreeService.iconSFSymbol(forFileExtension: fileExtension)
    }

    /// 获取文件显示名称
    /// - Parameter url: 文件 URL
    /// - Returns: 显示名称
    static func getFileName(for url: URL) -> String {
        FileTreeService.displayName(for: url)
    }

    /// 格式化文件修改日期
    /// - Parameter date: 日期
    /// - Returns: 格式化后的字符串
    static func formatDate(_ date: Date?) -> String {
        FileTreeService.formatDate(date)
    }

    /// 获取文件修改日期
    /// - Parameter url: 文件 URL
    /// - Returns: 修改日期
    static func getModificationDate(for url: URL) -> Date? {
        FileTreeService.modificationDate(for: url)
    }

    /// 检查文件是否应该显示修改日期
    /// - Parameter url: 文件 URL
    /// - Returns: 是否显示
    static func shouldShowModificationDate(for url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let documentExtensions = ["swift", "m", "h", "md", "txt", "json", "xml", "yaml", "yml"]
        return documentExtensions.contains(ext)
    }

    // MARK: - 文件系统查询

    /// 判断 URL 是否为目录
    /// - Parameter url: 文件或目录 URL
    /// - Returns: 是否为目录
    static func isDirectory(_ url: URL) -> Bool {
        FileTreeService.isDirectory(url)
    }

    /// 读取目录内容（过滤并排序后返回）
    /// - Parameter url: 目录 URL
    /// - Returns: 过滤并排序后的子项 URL 列表
    /// - Throws: 文件系统读取错误
    static func loadContents(of url: URL) throws -> [URL] {
        try FileTreeService.loadContents(of: url)
    }

    // MARK: - 文件操作

    /// 在指定目录下创建新文件
    @discardableResult
    static func createFile(in parentURL: URL, name: String) -> URL? {
        FileTreeService.createFile(in: parentURL, name: name)
    }

    /// 在指定目录下创建新文件夹
    @discardableResult
    static func createFolder(in parentURL: URL, name: String) -> URL? {
        FileTreeService.createFolder(in: parentURL, name: name)
    }

    /// 重命名文件或文件夹
    @discardableResult
    static func renameItem(at url: URL, newName: String) -> URL? {
        FileTreeService.renameItem(at: url, newName: newName)
    }

    /// 将文件或文件夹移入废纸篓
    @discardableResult
    static func trashItem(at url: URL) -> Bool {
        FileTreeService.trashItem(at: url)
    }

    // MARK: - 外部应用（插件特有，依赖 AppKit）

    /// 在终端中打开指定路径
    /// - Parameter url: 文件或目录 URL
    static func openInTerminal(_ url: URL) {
        let targetPath: String
        let isDir = FileTreeService.isDirectory(url)

        if isDir {
            targetPath = url.path
        } else {
            targetPath = url.deletingLastPathComponent().path
        }

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
            NSWorkspace.shared.open(url)
        }
    }

    /// 复制文件绝对路径到剪贴板
    /// - Parameter url: 文件 URL
    static func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    /// 在 Finder 中显示文件
    /// - Parameter url: 文件或目录 URL
    static func openInFinder(_ url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
}
