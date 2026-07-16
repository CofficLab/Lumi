import DownloadKit
import Foundation
import LumiCoreKit
import os
import SuperLogKit

/// Download Agent 插件
///
/// 提供一组下载相关的 Agent 工具，支持 HTTP/HTTPS 文件下载、
/// 批量下载、断点续传、进度追踪和任务管理。
public enum DownloadPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.download-agent",
        displayName: LumiPluginLocalization.string("Download Agent", bundle: .module),
        description: LumiPluginLocalization.string("File download agent toolkit: supports HTTP/HTTPS downloads, resumable transfers, batch downloads, progress queries, and task management.", bundle: .module),
        order: 92,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "arrow.down.circle",
    )

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.download-agent")

    /// 全局下载管理器，懒加载
    @MainActor public static var sharedManager: DownloadManager = {
        let dir = defaultDownloadDirectory()
        let config = DownloadManager.Configuration(
            downloadDirectory: dir,
            maxConcurrentDownloads: 3,
            timeoutInterval: 3600,
            enableResume: true
        )
        return DownloadManager(configuration: config)
    }()

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        let manager = sharedManager
        return [
            DownloadFileTool(manager: manager),
            DownloadBatchTool(manager: manager),
            ListDownloadsTool(manager: manager),
            DownloadProgressTool(manager: manager),
            CancelDownloadTool(manager: manager),
            RetryDownloadTool(manager: manager),
        ]
    }
}

// MARK: - Helpers

extension DownloadPlugin {
    /// 默认下载目录：用户的 ~/Downloads
    ///
    /// 直接复用用户下载目录，不再在其下创建二级子目录。仅计算目录 URL，不创建目录——
    /// 避免仅访问 `sharedManager`（懒加载触发本方法）就副作用地建目录。真正发起下载时，
    /// `DownloadManager.performDownload` 会为目标目录调用 `createDirectory`，按需创建。
    static func defaultDownloadDirectory() -> URL {
        let fileManager = FileManager.default
        guard let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            // 降级到临时目录
            return fileManager.temporaryDirectory.appendingPathComponent("LumiDownloads", isDirectory: true)
        }
        return downloads
    }

    /// 从 URL 字符串提取文件名
    static func extractFilename(from url: URL) -> String {
        let name = url.lastPathComponent
        // lastPathComponent 对 "/" 路径返回 "/"，对无路径的 URL 可能返回空
        if name.isEmpty || name == "/" { return "download_\(UUID().uuidString.prefix(8))" }
        return name
    }
}
