import os
import Foundation
import KernelCore
import KitSuperLog
import OpenInKit
import ProviderProject
import ProviderDocsView
import ProviderToolManager

/// 打开外部应用插件（合并版）。
///
/// 复刻自旧版 `OpenInFinderPlugin` / `OpenInXcodePlugin` / `OpenInCursorPlugin` /
/// `OpenInVSCodePlugin` / `OpenInAntigravityPlugin` / `OpenInGitHubDesktopPlugin` /
/// `OpenInGitOKPlugin` 系列：注册 7 个 Agent 工具，让 LLM 可在外部应用中
/// 打开当前项目或指定路径。
@MainActor
public final class OpenInPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.open-in", category: "OpenIn")

    /// 合并包的插件 ID（新版唯一入口）。
    public let id = "com.coffic.lumi.plugin.open-in"
    public let order = 61
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.open-in",
        name: "Open In",
        description: "",
        category: .integration,
        stage: .stable,
        policy: .enabledByDefault
    )

    public init() {}


    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }
        let project = kernel.resolveProvider((any ProjectProviding).self)

        let tools: [OpenInTool] = [
            OpenInTool(config: OpenInApps.finder, project: project),
            OpenInTool(config: OpenInApps.xcode, project: project),
            OpenInTool(config: OpenInApps.cursor, project: project),
            OpenInTool(config: OpenInApps.vscode, project: project),
            OpenInTool(config: OpenInApps.antigravity, project: project),
            OpenInTool(config: OpenInApps.gitHubDesktop, project: project),
            OpenInTool(config: OpenInApps.gitOK, project: project),
        ]
        for tool in tools {
        toolManager.add(tool, pluginID: id)
        kernel.resolveProvider((any DocsViewProviding).self)?.addAbout(
            DocsEntry(id: id, name: metadata.name) {
                OpenInKit.OpenInAboutView(displayName: OpenInApps.finder.displayName, systemImage: OpenInApps.finder.systemImage, toolName: OpenInApps.finder.toolName)
            }
        )
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }
        for config in [OpenInApps.finder, OpenInApps.xcode, OpenInApps.cursor, OpenInApps.vscode,
                       OpenInApps.antigravity, OpenInApps.gitHubDesktop, OpenInApps.gitOK] {
            toolManager.remove(id: config.toolName)
        }
    }
}
