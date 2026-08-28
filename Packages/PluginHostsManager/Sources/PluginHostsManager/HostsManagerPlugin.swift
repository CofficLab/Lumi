import KernelCore
import os
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderRootView
import KitSuperLog
import SwiftUI

/// Hosts Manager 插件（KernelCore 版本）
///
/// 由旧版 `Plugins/HostsManagerPlugin`（KernelLumi / LumiPlugin 架构）复刻而来：
/// - `onBoot` 注册 ActivityBar 入口（主内容 `HostsManagerView`）与「说明书」文档；
/// - `onShutdown` 撤回全部贡献。
///
/// 与旧版的对应关系：
/// - `viewContainers` → `ContentViewProviding.setContentView` + `ActivityBarProviding`；
/// - `pluginManualView` → `DocsViewProviding.addManual`；
/// - `titleToolbarItems` 居中标题不复刻（新版无容器激活语义，与 PluginDevice 一致）。
@MainActor
public final class HostsManagerPlugin: SuperPlugin, SuperLog {
    public let id = "com.coffic.lumi.plugin.hosts-manager"
    public let order = 21
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.hosts-manager",
        name: "Hosts Manager",
        description: "",
        category: .system,
        stage: .stable,
        policy: .disabledByDefault
    )

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.hosts-manager")
    public nonisolated static let verbose: Bool = false

    public init() {}

    public var name: String {
        LumiPluginLocalization.string("Hosts Manager", bundle: .module)
    }

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: name) { HostsManagerAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { HostsManagerManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)

        // ActivityBar 入口（沿用旧版 viewContainers）。
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: name,
                    systemImage: "list.bullet.rectangle",
                    order: order,
                    ownerPluginID: id
                ) { state in
                    if state == .activated {
                        contentView?.setContentView(AnyView(HostsManagerView()))
                        rootView?.setRailView(nil)
                        rootView?.setContentHeaderViewHidden(true)
                    } else {
                        rootView?.setRailView(railView?.makeRailView())
                        rootView?.setContentHeaderViewHidden(false)
                    }
                },
            ])
        } else {
            contentView?.setContentView(AnyView(HostsManagerView()))
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            let railView = kernel.resolveProvider((any RailViewProviding).self)
            let rootView = kernel.resolveProvider((any RootViewProviding).self)
            rootView?.setRailView(railView?.makeRailView())
            rootView?.setContentHeaderViewHidden(false)
        }
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
