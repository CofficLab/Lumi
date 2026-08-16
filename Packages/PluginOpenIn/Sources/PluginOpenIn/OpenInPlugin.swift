import Foundation
import KernelCore
import ProviderProject
import ProviderToolManager

/// 打开外部应用插件（合并版）。
///
/// 复刻自旧版 `OpenInFinderPlugin` / `OpenInXcodePlugin` / `OpenInCursorPlugin` /
/// `OpenInVSCodePlugin` / `OpenInAntigravityPlugin` / `OpenInGitHubDesktopPlugin` /
/// `OpenInGitOKPlugin` 系列：注册 7 个 Agent 工具，让 LLM 可在外部应用中
/// 打开当前项目或指定路径。
@MainActor
public final class OpenInPlugin: SuperPlugin {
    /// 合并包的插件 ID（新版唯一入口）。
    public let id = "com.coffic.lumi.plugin.open-in"
    public let order = 61

    public init() {}

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Open In",
            description: "Open the current project in Finder / Xcode / Cursor / VS Code / Antigravity / GitHub Desktop / GitOK",
            category: .chat,
            stage: .preview,
            policy: .alwaysOn
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else { return }
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
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else { return }
        for config in [OpenInApps.finder, OpenInApps.xcode, OpenInApps.cursor, OpenInApps.vscode,
                       OpenInApps.antigravity, OpenInApps.gitHubDesktop, OpenInApps.gitOK] {
            toolManager.remove(id: config.toolName)
        }
    }
}
