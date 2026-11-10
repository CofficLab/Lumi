import Foundation
import SwiftUI
import AppKit
import KitFileSystem

/// 文件树文件服务
/// 负责处理文件相关的无状态逻辑：图标、名称、过滤、排序等
///
/// 作为 FileTreeKit.FileTreeService 的薄包装层，
/// 保留插件特有的方法（openInTerminal、openInVSCode 等 UI 操作）。
public enum FileTreeFacade {
    // MARK: - 委托给 FileTreeKit

    /// 过滤并排序目录内容
    /// - Parameter urls: 目录下的 URL 列表
    /// - Returns: 过滤并排序后的 URL 列表（文件夹在前）
    public static func filterAndSortContents(_ urls: [URL]) -> [URL] {
        FileTreeService.filterAndSortContents(urls)
    }

    /// 获取文件图标
    /// - Parameter url: 文件 URL
    /// - Returns: 图标 SF Symbol 名称
    public static func getFileIcon(for url: URL) -> String {
        FileTreeService.iconSFSymbol(for: url)
    }

    /// 获取非目录文件图标，避免文件树行在 SwiftUI body 求值时反复查询文件系统资源值。
    /// - Parameter fileExtension: 文件扩展名
    /// - Returns: 图标 SF Symbol 名称
    public static func getFileIcon(fileExtension: String) -> String {
        FileTreeService.iconSFSymbol(forFileExtension: fileExtension)
    }

    /// 获取文件显示名称
    /// - Parameter url: 文件 URL
    /// - Returns: 显示名称
    public static func getFileName(for url: URL) -> String {
        FileTreeService.displayName(for: url)
    }

    /// 格式化文件修改日期
    /// - Parameter date: 日期
    /// - Returns: 格式化后的字符串
    public static func formatDate(_ date: Date?) -> String {
        FileTreeService.formatDate(date)
    }

    /// 获取文件修改日期
    /// - Parameter url: 文件 URL
    /// - Returns: 修改日期
    public static func getModificationDate(for url: URL) -> Date? {
        FileTreeService.modificationDate(for: url)
    }

    /// 检查文件是否应该显示修改日期
    /// - Parameter url: 文件 URL
    /// - Returns: 是否显示
    public static func shouldShowModificationDate(for url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let documentExtensions = ["swift", "m", "h", "md", "txt", "json", "xml", "yaml", "yml"]
        return documentExtensions.contains(ext)
    }

    // MARK: - 文件系统查询

    /// 判断 URL 是否为目录
    /// - Parameter url: 文件或目录 URL
    /// - Returns: 是否为目录
    public static func isDirectory(_ url: URL) -> Bool {
        FileTreeService.isDirectory(url)
    }

    /// 读取目录内容（过滤并排序后返回）
    /// - Parameter url: 目录 URL
    /// - Returns: 过滤并排序后的子项 URL 列表
    /// - Throws: 文件系统读取错误
    public static func loadContents(of url: URL) throws -> [URL] {
        try FileTreeService.loadContents(of: url)
    }

    // MARK: - 文件操作

    /// 在指定目录下创建新文件
    @discardableResult
    public static func createFile(in parentURL: URL, name: String) -> URL? {
        FileTreeService.createFile(in: parentURL, name: name)
    }

    /// 在指定目录下创建新文件夹
    @discardableResult
    public static func createFolder(in parentURL: URL, name: String) -> URL? {
        FileTreeService.createFolder(in: parentURL, name: name)
    }

    /// 重命名文件或文件夹
    @discardableResult
    public static func renameItem(at url: URL, newName: String) -> URL? {
        FileTreeService.renameItem(at: url, newName: newName)
    }

    /// 将文件或文件夹移入废纸篓
    @discardableResult
    public static func trashItem(at url: URL) -> Bool {
        FileTreeService.trashItem(at: url)
    }

    /// 批量移入废纸篓，自动跳过嵌套子路径。
    @discardableResult
    public static func trashItems(at urls: [URL]) -> Int {
        trashItemsReporting(at: urls).trashedURLs.count
    }

    /// 批量移入废纸篓的结果。
    ///
    /// 多选删除必须处理 `actionTargets(for:)` 的全部目标，并保留失败项供
    /// 调用方汇报部分失败（回归 #1109）。
    struct TrashBatchResult: Equatable {
        let trashedURLs: [URL]
        let failedURLs: [URL]

        var totalCount: Int { trashedURLs.count + failedURLs.count }
        var hasPartialFailure: Bool { !trashedURLs.isEmpty && !failedURLs.isEmpty }
    }

    /// 逐个尝试移入废纸篓并回报成功/失败目标；嵌套子路径会被跳过。
    static func trashItemsReporting(
        at urls: [URL],
        trash: (URL) -> Bool = { trashItem(at: $0) }
    ) -> TrashBatchResult {
        var trashedURLs: [URL] = []
        var failedURLs: [URL] = []
        for url in PathFormatter.topLevelURLs(from: urls) {
            if trash(url) {
                trashedURLs.append(url)
            } else {
                failedURLs.append(url)
            }
        }
        return TrashBatchResult(trashedURLs: trashedURLs, failedURLs: failedURLs)
    }

    /// 移动文件或文件夹到目标目录
    /// - Parameters:
    ///   - sourcePath: 源文件路径
    ///   - destPath: 目标目录路径
    /// - Returns: 成功返回新 URL，失败返回 nil
    @discardableResult
    public static func moveItem(from sourcePath: String, to destPath: String) -> URL? {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let destURL = URL(fileURLWithPath: destPath)

        // 如果目标是文件，则移动到该文件所在目录
        let targetDir: URL
        if isDirectory(destURL) {
            targetDir = destURL
        } else {
            targetDir = destURL.deletingLastPathComponent()
        }

        let fileName = sourceURL.lastPathComponent
        let finalURL = targetDir.appendingPathComponent(fileName)

        do {
            try FileManager.default.moveItem(at: sourceURL, to: finalURL)
            return finalURL
        } catch {
            return nil
        }
    }

    // MARK: - 外部应用（插件特有，依赖 AppKit）

    /// 在终端中打开指定路径
    /// - Parameter url: 文件或目录 URL
    public static func openInTerminal(_ url: URL) {
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
    ///
    /// `/usr/bin/env` 能启动不代表 `code` 命令存在：未安装 shell command 时，
    /// env 随后会以非零状态退出。必须等待并检查退出状态，失败时回退到
    /// VS Code 应用 URL，并通过 `completion` 报告最终结果（回归 #1105）。
    /// - Parameters:
    ///   - url: 文件或文件夹 URL
    ///   - completion: 每次打开尝试结束时在主线程回调最终是否成功
    public static func openInVSCode(
        _ url: URL,
        completion: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let status = runAndWait(
                executable: "/usr/bin/env",
                arguments: ["code", url.path]
            )
            Task { @MainActor in
                let opened = await resolveVSCodeOpen(commandStatus: status) {
                    await openWithVSCodeApplication(url)
                }
                completion(opened)
            }
        }
    }

    /// 只有 `code` 命令以 0 退出才算打开成功；命令缺失、无法启动或非零退出
    /// 都必须回退到应用打开。
    @MainActor
    static func resolveVSCodeOpen(
        commandStatus: Int32?,
        openApplication: () async -> Bool
    ) async -> Bool {
        if commandStatus == 0 {
            return true
        }
        return await openApplication()
    }

    /// 启动外部命令并等待退出，返回退出状态；无法启动进程时返回 nil。
    static func runAndWait(executable: String, arguments: [String]) -> Int32? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return nil
        }
    }

    /// 使用 VS Code 应用本身打开目标（不依赖 `code` shell command）。
    @MainActor
    private static func openWithVSCodeApplication(_ url: URL) async -> Bool {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.microsoft.VSCode"
        ) else {
            return false
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: appURL,
                configuration: configuration
            ) { _, error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    /// 复制文件绝对路径到剪贴板
    /// - Parameter url: 文件 URL
    public static func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    /// 在 Finder 中显示文件
    /// - Parameter url: 文件或目录 URL
    public static func openInFinder(_ url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
}
