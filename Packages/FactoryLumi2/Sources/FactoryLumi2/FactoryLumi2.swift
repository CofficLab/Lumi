import Foundation
import KernelCore
import ProviderProject
import ProviderToast

/// FactoryLumi2 — 工厂命名空间。
///
/// 负责创建 KernelCore 内核，并把各 Provider 包（如 ProviderProject、ProviderToast）
/// 的默认实现注册进内核。
@MainActor
public enum FactoryLumi2 {

    // MARK: - makeKernel

    /// 创建 KernelCore 内核，并注册默认实现：
    /// - `ProjectProviding` → `ProviderProject.DefaultProjectProviding`
    /// - `ToastProviding` → `ProviderToast.DefaultToastProviding`（no-op）
    ///
    /// - Returns: 已注册默认 Provider 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel() throws -> KernelCoreContainer {
        try makeKernel(
            projectProvider: DefaultProjectProviding(),
            toastProvider: DefaultToastProviding()
        )
    }

    /// 创建 KernelCore 内核，注册自定义 `ProjectProviding` 与默认 `ToastProviding`。
    ///
    /// - Parameter projectProvider: 由调用方提供的项目管理实现。
    /// - Returns: 已注册 Provider 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel(projectProvider: any ProjectProviding) throws -> KernelCoreContainer {
        try makeKernel(
            projectProvider: projectProvider,
            toastProvider: DefaultToastProviding()
        )
    }

    /// 创建 KernelCore 内核，注册默认 `ProjectProviding` 与自定义 `ToastProviding`。
    ///
    /// - Parameter toastProvider: 由调用方提供的 Toast 展示实现（通常为 UI 插件）。
    /// - Returns: 已注册 Provider 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel(toastProvider: any ToastProviding) throws -> KernelCoreContainer {
        try makeKernel(
            projectProvider: DefaultProjectProviding(),
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
