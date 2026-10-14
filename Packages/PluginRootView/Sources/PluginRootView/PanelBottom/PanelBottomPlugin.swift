import Foundation
import KernelCore
import LumiLoggingKit
import os
import ProviderPanelBottom
import ProviderRootView
import ProviderStorage
import SwiftUI

/// 底部面板（PanelBottom）宿主插件。
///
/// 职责：
/// - `onBoot` 注册 `PanelBottomProviding`（EditorPreview / Terminal 等插件
///   通过它贡献底部面板 tab 入口，类似 VS Code 底部面板的 PREVIEW / TERMINAL）；
/// - 观察入口变化：有入口时把 `PanelBottomView` 安装进 content footer 插槽，
///   入口清空时撤回容器；
/// - 持久化用户最后激活的 tab（`PanelBottomStateStore`）。
///
/// content footer 的**可见性**仍由 ActivityBar 的 `preservesContentFooter`
/// 与各工作区插件控制；本插件只负责容器内容的安装与撤回。
///
/// `order = 12`：晚于 RootViewPlugin（0）与 Storage（1），早于全部消费方
/// （EditorPreview=83、Terminal=279），保证消费方 `onBoot` 时可解析到 provider。
@MainActor
public final class PanelBottomPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.panel-bottom",
        category: "PanelBottom"
    )
    nonisolated static let verbose = true

    public static let pluginID = "com.coffic.lumi.plugin.panel-bottom"

    public let id = pluginID
    public let order = 12
    public let metadata = PluginMetadata(
        id: pluginID,
        name: "Panel Bottom",
        description: "Tabbed bottom panel hosting footer entries such as Preview and Terminal.",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    private var provider: PanelBottomProvider?
    private var rootView: (any RootViewProviding)?
    private var stateStore: PanelBottomStateStore?
    private var observationHandle: (any PanelBottomObserverHandle)?
    private var isContainerInstalled = false

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        rootView = kernel.resolveProvider((any RootViewProviding).self)
        let store = kernel
            .resolveProvider((any StorageProviding).self)
            .map { PanelBottomStateStore(directory: $0.pluginDataDirectory(for: id)) }
        stateStore = store

        if kernel.isProviderRegistered((any PanelBottomProviding).self),
           let existing = kernel.resolveProvider((any PanelBottomProviding).self) as? PanelBottomProvider {
            // 内核重启：复用宿主持有的 provider 实例。
            provider = existing
        } else {
            // 兜底撤除旧注册，保证内核重启不触发 providerAlreadyRegistered。
            kernel.unregisterProvider((any PanelBottomProviding).self)
            // store 由闭包强持有（无回指，不构成循环）：provider 的生命周期
            // 长于本插件实例，弱捕获会在重启后丢失持久化句柄。
            let provider = PanelBottomProvider(
                loadActiveItemID: { store?.loadActiveItemID() },
                saveActiveItemID: { store?.saveActiveItemID($0) }
            )
            try kernel.registerHostProvider((any PanelBottomProviding).self, provider)
            self.provider = provider
        }

        observationHandle = provider?.addPanelBottomObserver { [weak self] event in
            guard case .itemsChanged = event else { return }
            self?.syncFooterContainer()
        }
        syncFooterContainer()
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        observationHandle?.cancel()
        observationHandle = nil
        uninstallFooterContainer()
        // provider 通过 registerHostProvider 注册（宿主持有），保留注册状态
        // 以便内核重启复用；各消费插件在自己的 onShutdown 中撤回入口。
        provider = nil
        rootView = nil
        stateStore = nil
    }

    // MARK: - Footer 容器安装

    /// 按入口数量安装/卸载 content footer 中的 tab 容器。
    private func syncFooterContainer() {
        guard let provider else { return }
        if provider.hasVisibleItems {
            guard !isContainerInstalled else { return }
            rootView?.setContentFooterView(AnyView(PanelBottomView(provider: provider)))
            isContainerInstalled = true
            if Self.verbose {
                Self.logger.debug("\(self.t)install footer container: tabs=\(provider.items.map(\.id).joined(separator: ","), privacy: .public)")
            }
        } else {
            uninstallFooterContainer()
        }
    }

    private func uninstallFooterContainer() {
        guard isContainerInstalled else { return }
        rootView?.setContentFooterView(nil)
        isContainerInstalled = false
        if Self.verbose {
            Self.logger.debug("\(self.t)uninstall footer container")
        }
    }
}
