import Foundation
import KernelCore
import KitSuperLog
import LumiUI
import os
import ProviderConversationInput
import ProviderProject
import ProviderRailView
import ProviderStorage
import ProviderToast
import SwiftUI

/// 项目文件树插件（KernelCore 版本）
///
/// 由旧版 `Plugins/ProjectFileTreePlugin`（LumiPlugin）迁移而来：
/// - 在 Rail 侧边栏贡献 "Explorer" 标签，托管基于 NSCollectionView 的文件树
///   （TreeView），提供文件浏览、Git 状态徽标、拖放、增删改、多选等完整能力；
/// - 通过 `StorageProviding` 解析插件目录，供 `FileTreeSettings` 持久化展开状态；
/// - 通过 `ProjectProviding` / `ConversationInputProviding` / `ToastProviding`
///   注入文件树所需的项目、发送到对话与提示能力。
@MainActor
public final class ProjectFileTreePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.project-file-tree", category: "ProjectFileTree")
    public nonisolated static let emoji = "🌲"
    public nonisolated static let verbose = false

    // MARK: - 功能开关

    /// 是否启用 Git 状态徽标（基于系统 git 命令）。
    public nonisolated static let gitStatusEnabled = true
    /// 是否启用拖放（文件移动）。
    public nonisolated static let dragAndDropEnabled = true

    /// 插件唯一标识。
    public static let pluginID = "com.coffic.lumi.plugin.project-file-tree"

    /// 本插件 rail 面板的稳定标识（注册为 `RailTabItem.id`）。
    public nonisolated static let railTabID = "explorer"

    public let id = pluginID
    public let order = 30
    public let metadata = PluginMetadata(
        id: pluginID,
        name: "Project File Tree",
        description: "Browse project files with Git status, drag-and-drop and file operations in the Explorer rail.",
        version: "1.0.0",
        category: .project,
        stage: .preview,
        policy: .required
    )

    private var viewModel: ProjectFileTreeViewModel?
    private var projectObserver: ProjectProvidingObserver?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let viewModel = ProjectFileTreeViewModel()
        self.viewModel = viewModel

        // 通过 Storage service 解析插件目录，供 FileTreeSettings 持久化展开状态。
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            FileTreeSettings.shared.configure(
                pluginDirectory: storage.pluginDataDirectory(
                    for: ProjectFileTreePluginRuntimeBridge.pluginName
                )
            )
        } else {
            Self.logger.error("\(Self.t) StorageProviding not found")
        }

        // 组装文件树上下文（项目 / 对话输入 / Toast 提示）。
        let project = kernel.resolveProvider((any ProjectProviding).self)
        projectObserver?.cancel()
        projectObserver = nil
        if project == nil {
            Self.logger.error("\(Self.t) ProjectProviding not found")
        } else if let project {
            projectObserver = ProjectProvidingObserver(project: project, viewModel: viewModel)
        }

        let conversationInput = kernel.resolveProvider((any ConversationInputProviding).self)
        if conversationInput == nil {
            Self.logger.error("\(Self.t) ConversationInputProviding not found")
        }

        let toast = kernel.resolveProvider((any ToastProviding).self)
        if toast == nil {
            Self.logger.error("\(Self.t) ToastProviding not found")
        }

        let context = FileTreeContext(
            project: project,
            conversationInput: conversationInput,
            toast: toast
        )

        // 在 Rail 侧边栏注入 Explorer 标签。
        guard let railView = kernel.resolveProvider((any RailViewProviding).self) else {
            Self.logger.error("\(Self.t) RailViewProviding not found")
            return
        }

        railView.addTabs([
            RailTabItem(
                id: Self.railTabID,
                groupID: id,
                title: "Explorer",
                systemImage: "square.grid.2x2.fill",
                order: order
            ) {
                TreeView(context: context, viewModel: viewModel)
            }
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        projectObserver?.cancel()
        projectObserver = nil
        viewModel = nil
        kernel.resolveProvider((any RailViewProviding).self)?.removeTabs(ids: [Self.railTabID])
    }
}
