import Foundation
import KernelCore
import ProviderNetwork
import ProviderProject
import ProviderToast
import ProviderToolbar
import ProviderWindow

/// KernelFactory — 内核工厂。
///
/// 负责创建 KernelCore 内核，内部通过 `DefaultProviderFactory` 装配各 Provider
/// （Project / Toast / Network / Window / Toolbar）并注册进内核。
@MainActor
public enum KernelFactory {

    /// 创建 KernelCore 内核，装配并注册全部默认 Provider：
    /// - `ProjectProviding` → `DefaultProjectProviding`
    /// - `ToastProviding` → `DefaultToastProviding`（no-op）
    /// - `NetworkProviding` → `DefaultNetworkProviding`（URLSession）
    /// - `WindowProviding` → `DefaultWindowProviding`（占位根视图）
    /// - `ToolbarProviding` → `DefaultToolbarProviding`（按 placement 渲染）
    ///
    /// - Returns: 已装配默认 Provider 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel() throws -> KernelCoreContainer {
        let factory = DefaultProviderFactory()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ProjectProviding).self, factory.makeProjectProvider())
        try kernel.registerProvider((any ToastProviding).self, factory.makeToastProvider())
        try kernel.registerProvider((any NetworkProviding).self, factory.makeNetworkProvider())
        try kernel.registerProvider((any WindowProviding).self, factory.makeWindowProvider())
        try kernel.registerProvider((any ToolbarProviding).self, factory.makeToolbarProvider())
        return kernel
    }
}
