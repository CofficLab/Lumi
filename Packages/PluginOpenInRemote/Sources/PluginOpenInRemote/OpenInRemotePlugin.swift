import os
import Foundation
import KernelCore
import LumiLoggingKit
import ProviderDocsView
import ProviderGit
import ProviderProject
import ProviderToast
import ProviderToolManager
import ProviderToolbar

/// 在浏览器中打开项目远程仓库的插件。
///
/// 读取当前项目的 `origin` remote 地址，转换为 HTTPS web 链接，
/// 用默认浏览器打开。标题栏按钮与 Agent 工具共用同一套解析逻辑。
@MainActor
public final class OpenInRemotePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.open-in-remote", category: "OpenInRemote")

    public let id = "com.coffic.lumi.plugin.open-in-remote"
    public let order = 617
    public let dependencies = [
        "com.coffic.lumi.plugin.projects",
        "com.coffic.lumi.plugin.git",
    ]
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.open-in-remote",
        name: OpenInRemoteLocalization.string("Open In Remote"),
        description: OpenInRemoteLocalization.string("Open the project's remote repository in the default browser."),
        category: .integration,
        stage: .stable,
        policy: .disabledByDefault
    )

    /// 强持有能力 Adapter，保证 ViewModel 以弱引用消费时仍然有效。
    private var gitCapability: OpenInRemoteGitCapabilityAdapter?
    private var projectCapability: OpenInRemoteProjectCapabilityAdapter?
    private var toastCapability: OpenInRemoteToastCapabilityAdapter?

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) {
                OpenInRemoteAboutView()
            })
            docs.addManual(DocsEntry(id: id, name: metadata.name) {
                OpenInRemoteManualView()
            })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let project = kernel.resolveProvider((any ProjectProviding).self)
        let git = kernel.resolveProvider((any GitRepositoryReading).self)
        let toast = kernel.resolveProvider((any ToastProviding).self)

        // Adapter 由入口持有：ViewModel 只以弱引用消费它们。
        let gitCapability = OpenInRemoteGitCapabilityAdapter(provider: git)
        let projectCapability = OpenInRemoteProjectCapabilityAdapter(project: project)
        let toastCapability = OpenInRemoteToastCapabilityAdapter(toast: toast)
        self.gitCapability = gitCapability
        self.projectCapability = projectCapability
        self.toastCapability = toastCapability

        let resolver = RemoteRepositoryResolver(gitCapability: gitCapability)

        if let toolbar = kernel.resolveProvider((any ToolbarProviding).self) {
            toolbar.addToolbarItems([
                ToolbarItem(
                    id: "\(id).toolbar",
                    title: OpenInRemoteLocalization.string("Open In Remote"),
                    placement: .leading,
                    category: .global,
                    order: order
                ) {
                    OpenInRemoteToolbarView(
                        projectCapability: projectCapability,
                        resolver: resolver,
                        toastCapability: toastCapability
                    )
                },
            ])
        }

        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }

        let tool = OpenInRemoteTool(projectCapability: projectCapability, resolver: resolver)
        toolManager.add(tool, pluginID: id)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: ["\(id).toolbar"])

        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }
        toolManager.remove(id: OpenInRemoteConstants.toolName)

        gitCapability = nil
        projectCapability = nil
        toastCapability = nil
    }
}
