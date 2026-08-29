import KernelCore
import ProviderProject
import ProviderRootView
import SwiftUI

/// Open-file tabs contribution for the root content header.
///
/// The plugin consumes `ProjectProviding` and contributes its view through
/// `RootViewProviding`; it has no dependency on the code editor plugin.
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

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any ProjectProviding).self)
        }
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any RootViewProviding).self)
        }

        rootView.setContentHeaderView(AnyView(ProjectFilesTabStripView(project: project)))
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any RootViewProviding).self)?.setContentHeaderView(nil)
    }
}
