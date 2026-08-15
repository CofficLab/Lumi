import Foundation
import KernelCore
import ProviderProject
import ProviderToast

/// KernelFactory — 内核工厂命名空间。
///
/// 负责创建 KernelCore 内核，并通过 `ProviderFactory` 产出各 Provider
/// （如 ProviderProject、ProviderToast）注册进内核。
@MainActor
public enum KernelFactory {

    // MARK: - makeKernel

    /// 创建 KernelCore 内核，并使用默认 `DefaultProviderFactory` 产出并注册全部 Provider：
    /// - `ProjectProviding` → `DefaultProjectProviding`
    /// - `ToastProviding` → `DefaultToastProviding`（no-op）
    ///
    /// - Returns: 已注册默认 Provider 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel() throws -> KernelCoreContainer {
        try makeKernel(providers: DefaultProviderFactory())
    }

    /// 创建 KernelCore 内核，并使用自定义 `ProviderFactory` 产出并注册全部 Provider。
    ///
    /// - Parameter providers: 负责产出各 Provider 实现的工厂。
    /// - Returns: 已注册 Provider 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel(providers: any ProviderFactory) throws -> KernelCoreContainer {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ProjectProviding).self, providers.makeProjectProvider())
        try kernel.registerProvider((any ToastProviding).self, providers.makeToastProvider())
        return kernel
    }

    /// 创建 KernelCore 内核，注册自定义 `ProjectProviding` 与默认 `ToastProviding`。
    ///
    /// - Parameter projectProvider: 由调用方提供的项目管理实现。
    /// - Returns: 已注册 Provider 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel(projectProvider: any ProjectProviding) throws -> KernelCoreContainer {
        try makeKernel(
            projectProvider: projectProvider,
            toastProvider: DefaultProviderFactory().makeToastProvider()
        )
    }

    /// 创建 KernelCore 内核，注册默认 `ProjectProviding` 与自定义 `ToastProviding`。
    ///
    /// - Parameter toastProvider: 由调用方提供的 Toast 展示实现（通常为 UI 插件）。
    /// - Returns: 已注册 Provider 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel(toastProvider: any ToastProviding) throws -> KernelCoreContainer {
        try makeKernel(
            projectProvider: DefaultProviderFactory().makeProjectProvider(),
            toastProvider: toastProvider
        )
    }

    /// 创建 KernelCore 内核，注册自定义 `ProjectProviding` 与 `ToastProviding`。
    ///
    /// - Parameters:
    ///   - projectProvider: 由调用方提供的项目管理实现。
    ///   - toastProvider: 由调用方提供的 Toast 展示实现（通常为 UI 插件）。
    /// - Returns: 已注册 Provider 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel(
        projectProvider: any ProjectProviding,
        toastProvider: any ToastProviding
    ) throws -> KernelCoreContainer {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ProjectProviding).self, projectProvider)
        try kernel.registerProvider((any ToastProviding).self, toastProvider)
        return kernel
    }
}
