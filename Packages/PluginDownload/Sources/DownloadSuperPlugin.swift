import KitAgentTool
import KitDownload
import Foundation
import KernelCore
import ProviderToolManager

@MainActor public final class DownloadSuperPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.download-agent"; public let order = 92
    public let metadata = PluginMetadata(id: "com.coffic.lumi.plugin.download-agent", name: "Download Agent", description: "Download files with progress tracking and batch support.", category: .project, stage: .preview, policy: .alwaysOn)
    public init() {}
    public func onBoot(kernel: KernelCoreContainer) throws { let tools = kernel.resolveProvider((any ToolManagerProviding).self); tools?.add(DownloadFileV2Tool(), pluginID: id); tools?.add(DownloadBatchV2Tool(), pluginID: id); tools?.add(DownloadRetryV2Tool(), pluginID: id); tools?.add(DownloadListV2Tool(), pluginID: id); tools?.add(DownloadProgressV2Tool(), pluginID: id); tools?.add(DownloadCancelV2Tool(), pluginID: id) }
    public func onShutdown(kernel: KernelCoreContainer) throws { let tools = kernel.resolveProvider((any ToolManagerProviding).self); [DownloadFileV2Tool.toolName, DownloadBatchV2Tool.toolName, DownloadRetryV2Tool.toolName, DownloadListV2Tool.toolName, DownloadProgressV2Tool.toolName, DownloadCancelV2Tool.toolName].forEach { tools?.remove(id: $0) } }
}

public struct DownloadListV2Tool: SuperAgentTool { public static let toolName = "list_downloads"; public let name = toolName; public init() {}; public func description(for: LanguagePreference) -> String { "List current download tasks." }; public func inputSchema(for: LanguagePreference) -> [String: Any] { ["type": "object", "properties": [:]] }; public func displayDescription(for: [String: ToolArgument]) -> String { "列出所有下载任务" }; public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }; public func execute(arguments: [String: ToolArgument]) async throws -> String { let states = await DownloadRuntime.manager.allTaskStates(); guard !states.isEmpty else { return "📋 当前没有下载任务" }; return (["📋 当前下载任务:"] + states.map { "\($0.key): \(String(describing: $0.value))" }).joined(separator: "\n") } }
public struct DownloadProgressV2Tool: SuperAgentTool { public static let toolName = "download_progress"; public let name = toolName; public init() {}; public func description(for: LanguagePreference) -> String { "Query detailed progress for a download task." }; public func inputSchema(for: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["task_id": ["type": "string"]], "required": ["task_id"]] }; public func displayDescription(for: [String: ToolArgument]) -> String { "查询下载进度" }; public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }; public func execute(arguments: [String: ToolArgument]) async throws -> String { guard let id = arguments["task_id"]?.value as? String else { return "❌ 错误：task_id 参数必需" }; guard let state = await DownloadRuntime.manager.state(for: id) else { return "❌ 未找到任务: \(id)" }; return "任务 ID: \(id)\n状态: \(String(describing: state))" } }
public struct DownloadCancelV2Tool: SuperAgentTool { public static let toolName = "cancel_download"; public let name = toolName; public init() {}; public func description(for: LanguagePreference) -> String { "Cancel an ongoing download task." }; public func inputSchema(for: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["task_id": ["type": "string"]], "required": ["task_id"]] }; public func displayDescription(for: [String: ToolArgument]) -> String { "取消下载" }; public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }; public func execute(arguments: [String: ToolArgument]) async throws -> String { guard let id = arguments["task_id"]?.value as? String else { return "❌ 错误：task_id 参数必需" }; guard let state = await DownloadRuntime.manager.state(for: id) else { return "❌ 未找到任务: \(id)" }; switch state { case .pending, .downloading: await DownloadRuntime.manager.cancel(taskId: id); return "✅ 已取消下载\n任务 ID: \(id)"; case .completed: return "⚠️ 任务已完成，无需取消\n任务 ID: \(id)"; case .cancelled: return "⚠️ 任务已被取消\n任务 ID: \(id)"; case .failed: return "⚠️ 任务已失败，无需取消\n任务 ID: \(id)" } } }

public struct DownloadFileV2Tool: SuperAgentTool {
    public static let toolName = "download_file"; public let name = toolName; public init() {}
    public func description(for language: LanguagePreference) -> String { "Download a single HTTP/HTTPS file with automatic resume. Filename and destination directory are optional." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["url": ["type": "string"], "filename": ["type": "string"], "directory": ["type": "string"]], "required": ["url"]] }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "下载文件" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let raw = arguments["url"]?.value as? String, let url = URL(string: raw), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return "❌ 错误：无效的 URL" }
        let filename = (arguments["filename"]?.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? DownloadPlugin.extractFilename(from: url)
        let directory = (arguments["directory"]?.value as? String).map { URL(fileURLWithPath: $0, isDirectory: true) } ?? DownloadPlugin.defaultDownloadDirectory()
        let id = UUID().uuidString
        let task = DownloadTask(id: id, url: url, destination: directory.appendingPathComponent(filename), expectedSize: nil); await DownloadRuntime.tasks.remember(task)
        do { let file = try await DownloadRuntime.manager.download(task); return "✅ 下载完成\n文件名: \(filename)\n任务 ID: \(id)\n路径: \(file.path)" }
        catch { return "❌ 下载失败: \(error.localizedDescription)\n任务 ID: \(id)" }
    }
}

public struct DownloadRetryV2Tool: SuperAgentTool { public static let toolName = "retry_download"; public let name = toolName; public init() {}; public func description(for: LanguagePreference) -> String { "Retry a failed or cancelled tracked download." }; public func inputSchema(for: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["task_id": ["type": "string"]], "required": ["task_id"]] }; public func displayDescription(for: [String: ToolArgument]) -> String { "重试下载" }; public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }; public func execute(arguments: [String: ToolArgument]) async throws -> String { guard let oldID = arguments["task_id"]?.value as? String, let old = await DownloadRuntime.tasks.task(id: oldID) else { return "❌ 无法获取任务详情: \(arguments["task_id"]?.value as? String ?? "")" }; guard let state = await DownloadRuntime.manager.state(for: oldID) else { return "❌ 未找到任务: \(oldID)" }; guard case .failed = state else { guard case .cancelled = state else { return "⚠️ 任务当前不可重试\n任务 ID: \(oldID)" }; return try await retry(old) }; return try await retry(old) }; private func retry(_ old: DownloadTask) async throws -> String { let task = DownloadTask(id: UUID().uuidString, url: old.url, destination: old.destination, expectedSize: old.expectedSize); await DownloadRuntime.tasks.remember(task); do { let file = try await DownloadRuntime.manager.download(task); return "✅ 重试成功\n文件名: \(file.lastPathComponent)\n任务 ID: \(task.id)\n路径: \(file.path)" } catch { return "❌ 重试失败: \(error.localizedDescription)\n任务 ID: \(task.id)" } } }

public struct DownloadBatchV2Tool: SuperAgentTool {
    public static let toolName = "download_batch"; public let name = toolName; public init() {}
    public func description(for: LanguagePreference) -> String { "Download multiple HTTP/HTTPS files, preserving task tracking for every item." }
    public func inputSchema(for: LanguagePreference) -> [String: Any] { ["type": "object", "properties": ["urls": ["type": "array", "items": ["type": "string"]], "directory": ["type": "string"]], "required": ["urls"]] }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "批量下载" }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let rawURLs: [String]
        if let values = arguments["urls"]?.value as? [String] { rawURLs = values }
        else if let values = arguments["urls"]?.value as? [Any] { rawURLs = values.compactMap { $0 as? String } }
        else { rawURLs = [] }
        let urls = rawURLs.compactMap(URL.init(string:)).filter { ["http", "https"].contains($0.scheme?.lowercased() ?? "") }
        guard !urls.isEmpty else { return "❌ 错误：urls 参数必需且必须是 HTTP/HTTPS 字符串数组" }
        let directory = (arguments["directory"]?.value as? String).map { URL(fileURLWithPath: $0, isDirectory: true) } ?? DownloadPlugin.defaultDownloadDirectory()
        var lines = ["📊 下载完成", "保存目录: \(directory.path)"]
        for url in urls { let id = UUID().uuidString; let name = DownloadPlugin.extractFilename(from: url); let task = DownloadTask(id: id, url: url, destination: directory.appendingPathComponent(name), expectedSize: nil); await DownloadRuntime.tasks.remember(task); do { _ = try await DownloadRuntime.manager.download(task); lines.append("✅ \(name)\n任务 ID: \(id)") } catch { lines.append("❌ 失败: \(name) — \(error.localizedDescription)\n任务 ID: \(id)") } }
        return lines.joined(separator: "\n")
    }
}
