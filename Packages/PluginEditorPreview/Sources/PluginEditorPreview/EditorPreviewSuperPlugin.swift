import KernelCore
import ProviderProject
import ProviderRootView
import ProviderStorage
import SwiftUI

/// Provides the editor preview through the root content footer slot.
@MainActor
public final class EditorPreviewSuperPlugin: SuperPlugin {
    public static let pluginID = "com.coffic.lumi.plugin.editor-preview"

    public let id = pluginID
    public let order = 83
    public let dependencies = [
        "com.coffic.lumi.plugin.projects",
    ]
    public let metadata = PluginMetadata(
        id: pluginID,
        name: EditorPreviewLocalization.string("Editor Preview"),
        description: "Renders Markdown and image files in the editor content footer.",
        version: "1.0.0",
        category: .editor,
        stage: .preview,
        policy: .enabledByDefault
    )

    private weak var rootView: (any RootViewProviding)?
    private var viewModel: EditorPreviewViewModel?
    private var projectObserver: EditorPreviewProjectObserver?
    private var isFooterInstalled = false

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any ProjectProviding).self)
        }
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any RootViewProviding).self)
        }

        let viewModel = EditorPreviewViewModel(project: project)
        let observer = EditorPreviewProjectObserver(
            project: project,
            viewModel: viewModel
        ) { [weak self, weak rootView, weak viewModel] fileURL in
            guard let self, let rootView, let viewModel else { return }
            self.updateFooterVisibility(
                for: fileURL,
                rootView: rootView,
                viewModel: viewModel
            )
        }

        self.rootView = rootView
        self.viewModel = viewModel
        self.projectObserver = observer
        updateFooterVisibility(for: project.currentFileURL, rootView: rootView, viewModel: viewModel)

        let heightStore = kernel
            .resolveProvider((any StorageProviding).self)
            .map { storage in
                FileContentFooterHeightStore(
                    fileURL: storage
                        .pluginDataDirectory(for: Self.pluginID)
                        .appendingPathComponent("content-footer-height.plist", isDirectory: false)
                )
            }
        rootView.activateContentFooterHeightProfile(
            ownerID: Self.pluginID,
            recommended: .standard,
            store: heightStore
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        projectObserver?.cancel()
        projectObserver = nil
        rootView?.setContentFooterView(nil)
        rootView?.deactivateContentFooterHeightProfile(ownerID: Self.pluginID)
        isFooterInstalled = false
        rootView = nil
        viewModel = nil
    }

    private func updateFooterVisibility(
        for fileURL: URL?,
        rootView: any RootViewProviding,
        viewModel: EditorPreviewViewModel
    ) {
        let shouldInstall = fileURL != nil && viewModel.state.showsPreviewFooter
        guard shouldInstall != isFooterInstalled else { return }
        isFooterInstalled = shouldInstall
        rootView.setContentFooterView(
            shouldInstall ? AnyView(EditorPreviewView(viewModel: viewModel)) : nil
        )
    }
}
