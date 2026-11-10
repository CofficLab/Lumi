import Combine
import Foundation
import KernelCore
import LumiLoggingKit
import os
import ProviderDocsView
import ProviderToast

// MARK: - Toast SuperPlugin

/// Shared Toast plugin for Lumi-family applications.
///
/// The plugin registers a concrete `ToastProviding` implementation and, when
/// the host exposes `RootViewProviding`, mounts the standard toast and error
/// overlays at the outermost root-view boundary.
@MainActor
public final class ToastSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.toast",
        category: "Toast"
    )

    /// 默认插件标识。宿主可在装配时传入自己的 id。
    public static let defaultPluginID = "com.coffic.lumi.plugin.toast"

    public let id: String
    public let order = 10
    public let metadata: PluginMetadata

    /// The observable state machine rendered by `ToastOverlay`.
    public let center = ToastCenter()

    /// Stable root-overlay identifier used for mounting and removal.
    public static let overlayID = "lumi-plugin-toast"

    public typealias OverlayInstaller = @MainActor (
        _ kernel: KernelCoreContainer,
        _ center: ToastCenter
    ) -> Void
    public typealias OverlayUninstaller = @MainActor (_ kernel: KernelCoreContainer) -> Void

    private let overlayInstaller: OverlayInstaller?
    private let overlayUninstaller: OverlayUninstaller?

    /// Creates the shared Toast plugin.
    ///
    /// Root-view implementations differ between host applications. The host
    /// therefore injects the small mount/unmount operation instead of the
    /// shared package depending on one concrete RootViewProviding module.
    ///
    /// - Parameters:
    ///   - id: 插件唯一标识，决定 `PluginMetadata.id` 与 About 条目 id。
    ///   - overlayInstaller: 宿主注入的浮层挂载操作。
    ///   - overlayUninstaller: 宿主注入的浮层卸载操作。
    public init(
        id: String = ToastSuperPlugin.defaultPluginID,
        overlayInstaller: OverlayInstaller? = nil,
        overlayUninstaller: OverlayUninstaller? = nil
    ) {
        self.id = id
        self.metadata = PluginMetadata(
            id: id,
            name: "Toast",
            description: "Shared toast and persistent error notifications",
            category: .core,
            stage: .stable,
            policy: .required
        )
        self.overlayInstaller = overlayInstaller
        self.overlayUninstaller = overlayUninstaller
    }

    public func onRegister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.addAbout(
            DocsEntry(id: id, name: metadata.name) { ToastAboutView() }
        )
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        // Replace the host's no-op fallback before other plugins resolve the
        // provider during their own boot phase.
        kernel.unregisterProvider((any ToastProviding).self)
        try kernel.registerProvider((any ToastProviding).self, center)

        overlayInstaller?(kernel, center)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        center.dismiss()
        overlayUninstaller?(kernel)
    }
}
