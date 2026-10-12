import KernelCore
import ProviderPanelBottom
import ProviderProject
import ProviderRootView
import ProviderStorage
import SwiftUI

/// Provides the editor preview through a Preview tab in the PanelBottom bottom panel.
///
/// 选中可预览文件（Markdown / 图片）时向 `PanelBottomProviding` 注册 Preview 入口，
/// 否则撤回入口；底部面板容器的安装与 footer 可见性分别由 PanelBottom 宿主插件
/// 与 ActivityBar（`preservesContentFooter`）负责，本插件不再直接写入
/// `RootViewProviding.setContentFooterView`。
@MainActor
public final class EditorPreviewSuperPlugin: SuperPlugin {
    public static let pluginID = "com.coffic.lumi.plugin.editor-preview"

    /// Preview 入口的 tab id。
    private static let previewTabID = "\(pluginID).preview"

    public let id = pluginID
    public let order = 83
    public let dependencies = [
        "com.coffic.lumi.plugin.projects",
    ]
    public let metadata = PluginMetadata(
        id: pluginID,
        name: EditorPreviewLocalization.string("Editor Preview"),
        description: EditorPreviewLocalization.string("Renders Markdown and image files in the editor content footer."),
        version: "1.0.0",
        category: .editor,
        stage: .preview,
        policy: .enabledByDefault
    )

    private weak var rootView: (any RootViewProviding)?
    private var panelBottom: (any PanelBottomProviding)?
    private var viewModel: EditorPreviewViewModel?
    private var projectObserver: EditorPreviewProjectObserver?
    private var isTabRegistered = false

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any ProjectProviding).self)
        }
        guard let rootView = kernel.resolveProvider((any RootViewProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any RootViewProviding).self)
        }
        if kernel.isProviderRegistered((any PanelBottomProviding).self) {
            panelBottom = kernel.resolveProvider((any PanelBottomProviding).self)
        }

        let viewModel = EditorPreviewViewModel(
            projectCapability: EditorPreviewProjectCapabilityAdapter(project: project)
        )
        let observer = EditorPreviewProjectObserver(
            project: project,
            viewModel: viewModel
        ) { [weak self, weak viewModel] fileURL in
            guard let self, let viewModel else { return }
            self.updateFooterTab(for: fileURL, viewModel: viewModel)
        }

        self.rootView = rootView
        self.viewModel = viewModel
        self.projectObserver = observer
        updateFooterTab(for: project.currentFileURL, viewModel: viewModel)

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
        // 撤回 Preview 入口；footer 容器的安装/撤回由 PanelBottom 宿主统一管理。
        panelBottom?.removeItems(ownerPluginID: Self.pluginID)
        panelBottom = nil
        rootView?.deactivateContentFooterHeightProfile(ownerID: Self.pluginID)
        isTabRegistered = false
        rootView = nil
        viewModel = nil
    }

    /// 运行时启用：按当前文件重新同步 Preview 入口。
    ///
    /// 启动时被跳过、从未 Boot 的插件走 `onBoot` 完整初始化；曾 Boot 过
    /// 再启用的插件只走本方法。
    public func onEnable(kernel: KernelCoreContainer) async throws {
        guard let project = kernel.resolveProvider((any ProjectProviding).self),
              let viewModel else { return }
        if kernel.isProviderRegistered((any PanelBottomProviding).self) {
            panelBottom = kernel.resolveProvider((any PanelBottomProviding).self)
        }
        isTabRegistered = false
        updateFooterTab(for: project.currentFileURL, viewModel: viewModel)
    }

    /// 运行时禁用：撤回 Preview 入口（内核不会代撤 Provider 侧贡献）。
    public func onDisable(kernel: KernelCoreContainer) async throws {
        panelBottom?.removeItems(ownerPluginID: Self.pluginID)
        isTabRegistered = false
    }

    // MARK: - Preview 入口注册

    /// 按当前文件是否可预览注册/撤回 Preview 入口。
    private func updateFooterTab(for fileURL: URL?, viewModel: EditorPreviewViewModel) {
        let shouldRegister = fileURL != nil && viewModel.state.showsPreviewFooter
        guard shouldRegister != isTabRegistered else { return }
        isTabRegistered = shouldRegister
        if shouldRegister {
            panelBottom?.addItems([PanelBottomItem(
                id: Self.previewTabID,
                title: EditorPreviewLocalization.string("Preview"),
                systemImage: "eye",
                // tab 权重派生自插件 order，相对顺序由插件目录统一决定。
                order: order,
                ownerPluginID: Self.pluginID
            ) { [weak viewModel] in
                guard let viewModel else { return AnyView(EmptyView()) }
                return AnyView(EditorPreviewView(viewModel: viewModel))
            }])
        } else {
            panelBottom?.removeItems(ownerPluginID: Self.pluginID)
        }
    }
}
