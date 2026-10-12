import Foundation
import KernelCore
import LumiLoggingKit
import os
import ProviderRootView

/// RootView 的生命周期插件。
///
/// `LumiRootViewProvider` 负责根布局本身；本插件负责把宿主选择的
/// `RootViewProviding` 实现接入 KernelCore。这样 ProviderFactory 只负责
/// 产出实现，Provider 的注册与撤销则遵循统一的插件生命周期。
@MainActor
public final class RootViewPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.root-view",
        category: "RootView"
    )

    public static let pluginID = "com.coffic.lumi.plugin.root-view"

    public let id = "com.coffic.lumi.plugin.root-view"
    public let order = 0
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.root-view",
        name: "Root View",
        description: "Provides the application's root layout",
        category: .system,
        stage: .stable,
        policy: .alwaysOn
    )

    public let provider: any RootViewProviding

    public init(provider: any RootViewProviding) {
        self.provider = provider
    }

    public convenience init() {
        self.init(provider: LumiRootViewProvider())
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 允许宿主在启动前注册的实现被 RootViewPlugin 的显式选择覆盖，
        // 同时保证重启内核时不会触发 providerAlreadyRegistered。
        kernel.unregisterProvider((any RootViewProviding).self)
        try kernel.registerProvider((any RootViewProviding).self, provider)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.unregisterProvider((any RootViewProviding).self)
    }
}
