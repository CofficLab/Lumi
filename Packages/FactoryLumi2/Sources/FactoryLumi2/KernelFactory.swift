import Foundation
import KernelCore
import ProviderActivityBar
import ProviderNetwork
import ProviderProject
import ProviderRootView
import ProviderToast
import ProviderToolbar

/// KernelFactory — 内核工厂。
///
/// 负责创建 KernelCore 内核，内部通过 `DefaultProviderFactory` 装配各 Provider
/// （Project / Toast / Network / Toolbar / RootView / ActivityBar）并注册进内核。
@MainActor
public enum KernelFactory {

    /// 创建 KernelCore 内核，装配并注册全部默认 Provider：
    /// - `ProjectProviding` → `DefaultProjectProviding`
    /// - `ToastProviding` → `DefaultToastProviding`（no-op）
    /// - `NetworkProviding` → `DefaultNetworkProviding`（URLSession）
    /// - `ToolbarProviding` → `DefaultToolbarProviding`（按 placement 渲染）
    /// - `RootViewProviding` → `DefaultRootViewProviding`（工具栏 + 内容区）
    /// - `ActivityBarProviding` → `DefaultActivityBarProviding`（竖直入口栏）
    ///
    /// - Returns: 已装配默认 Provider 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel() throws -> KernelCoreContainer {
        let factory = DefaultProviderFactory()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ProjectProviding).self, factory.makeProjectProvider())
        try kernel.registerProvider((any ToastProviding).self, factory.makeToastProvider())
        try kernel.registerProvider((any NetworkProviding).self, factory.makeNetworkProvider())
        try kernel.registerProvider((any ToolbarProviding).self, factory.makeToolbarProvider())
        try kernel.registerProvider((any RootViewProviding).self, factory.makeRootViewProvider())
        try kernel.registerProvider((any ActivityBarProviding).self, factory.makeActivityBarProvider())
        return kernel
    }
}
