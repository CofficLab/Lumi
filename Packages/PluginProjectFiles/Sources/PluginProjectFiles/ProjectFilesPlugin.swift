import KernelCore
import ProviderActivityBar
import ProviderProject
import ProviderRootView
import SwiftUI

/// Open-file tabs contribution for the root content header.
///
/// The plugin consumes `ProjectProviding` and contributes its view through
/// `RootViewProviding`; it has no dependency on the code editor plugin.
///
/// The content header is automatically hidden when no files are open,
/// and shown again once files become available.
@MainActor
public final class ProjectFilesPlugin: SuperPlugin {
    public static let pluginID = "com.coffic.lumi.plugin.project-files"

    public let id = ProjectFilesPlugin.pluginID
    public let order = 81
    public let dependencies = [
        "com.coffic.lumi.plugin.projects",
    ]
    public let metadata = PluginMetadata(
        id: ProjectFilesPlugin.pluginID,
        name: "Project Files",
        description: "Shows and controls files open in the current project.",
        version: "1.0.0",
        category: .editor,
        stage: .preview,
        policy: .required
    )

    private weak var rootView: (any RootViewProviding)?
    private weak var activityBar: (any ActivityBarProviding)?
    private var projectObserver: ProjectFilesProjectObserver?
    private var tabViewModel: ProjectFilesTabViewModel?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any ProjectProviding).self)
        }
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any RootViewProviding).self)
        }

        let tabViewModel = ProjectFilesTabViewModel(
            projectCapability: ProjectFilesProjectCapabilityAdapter(project: project)
        )
        let projectObserver = ProjectFilesProjectObserver(project: project) { [weak self] in
            tabViewModel.reload()
            self?.updateHeaderVisibility(for: project)
        }
        self.rootView = rootView
        self.activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        self.tabViewModel = tabViewModel
        self.projectObserver = projectObserver
        rootView.setContentHeaderView(AnyView(ProjectFilesTabStripView(viewModel: tabViewModel)))
        updateHeaderVisibility(for: project)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        projectObserver?.cancel()
        projectObserver = nil
        tabViewModel = nil
        activityBar = nil
        kernel.resolveProvider((any RootViewProviding).self)?.setContentHeaderView(nil)
    }

    /// 有打开文件且文件工作区处于激活状态时显示 content header，否则隐藏。
    ///
    /// 只有声明 `preservesContentHeader` 的工作区（文件浏览/编辑）拥有标签条；
    /// 其它工作区（如 Terminal）激活后，项目事件恢复打开文件不能把标签条
    /// 重新显示到其内容上方。无 ActivityBar 的宿主保持旧行为（#1015）。
    private func updateHeaderVisibility(for project: any ProjectProviding) {
        let hasFiles = !project.openFileURLs.isEmpty || project.currentFileURL != nil
        guard hasFiles else {
            rootView?.setContentHeaderViewHidden(true)
            return
        }
        guard activeWorkspacePreservesContentHeader else { return }
        rootView?.setContentHeaderViewHidden(false)
    }

    private var activeWorkspacePreservesContentHeader: Bool {
        guard let activityBar else { return true }
        guard let activeID = activityBar.activeItemID,
              let activeItem = activityBar.items.first(where: { $0.id == activeID }) else {
            return true
        }
        return activeItem.preservesContentHeader
    }
}
