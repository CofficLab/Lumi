import KernelCore
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
public final class ProjectFilesSuperPlugin: SuperPlugin {
    public static let pluginID = "com.coffic.lumi.plugin.project-files"

    public let id = ProjectFilesSuperPlugin.pluginID
    public let order = 81
    public let dependencies = [
        "com.coffic.lumi.plugin.projects",
    ]
    public let metadata = PluginMetadata(
        id: ProjectFilesSuperPlugin.pluginID,
        name: "Project Files",
        description: "Shows and controls files open in the current project.",
        version: "1.0.0",
        category: .editor,
        stage: .preview,
        policy: .required
    )

    private weak var rootView: (any RootViewProviding)?
    private var projectObserver: (any ProjectProvidingObserverHandle)?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any ProjectProviding).self)
        }
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any RootViewProviding).self)
        }

        self.rootView = rootView
        rootView.setContentHeaderView(AnyView(ProjectFilesTabStripView(project: project)))

        let projectObserver = project.addObserver { [weak self] _ in
            self?.updateHeaderVisibility(for: project)
        }
        self.projectObserver = projectObserver
        updateHeaderVisibility(for: project)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        projectObserver?.cancel()
        projectObserver = nil
        kernel.resolveProvider((any RootViewProviding).self)?.setContentHeaderView(nil)
    }

    /// 有打开文件时显示 content header，无文件时隐藏。
    private func updateHeaderVisibility(for project: any ProjectProviding) {
        let hasFiles = !project.openFileURLs.isEmpty || project.currentFileURL != nil
        rootView?.setContentHeaderViewHidden(!hasFiles)
    }
}
