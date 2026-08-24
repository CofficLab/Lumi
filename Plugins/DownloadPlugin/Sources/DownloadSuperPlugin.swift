import AgentToolKit
import DownloadKit
import Foundation
import KernelCore
import ProviderToolManager

@MainActor public final class DownloadSuperPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.download-agent"; public let order = 92
    public let metadata = PluginMetadata(id: "com.coffic.lumi.plugin.download-agent", name: "Download Agent", description: "Download files with progress tracking and batch support.", category: .project, stage: .preview, policy: .alwaysOn)
    public init() {}
    public func onBoot(kernel: KernelCoreContainer) throws { kernel.resolveProvider((any ToolManagerProviding).self)?.add(DownloadFileV2Tool(), pluginID: id) }
    public func onShutdown(kernel: KernelCoreContainer) throws { kernel.resolveProvider((any ToolManagerProviding).self)?.remove(id: DownloadFileV2Tool.toolName) }
}

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
        do { let file = try await DownloadRuntime.manager.download(DownloadTask(id: id, url: url, destination: directory.appendingPathComponent(filename), expectedSize: nil)); return "✅ 下载完成\n文件名: \(filename)\n任务 ID: \(id)\n路径: \(file.path)" }
        catch { return "❌ 下载失败: \(error.localizedDescription)\n任务 ID: \(id)" }
    }
}
