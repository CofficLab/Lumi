import Foundation
import KernelCore
import ProviderProject

/// FactoryLumi2 — 工厂命名空间。
///
/// 负责创建 KernelCore 内核，并把各 Provider 包（如 ProviderProject）注册进内核。
@MainActor
public enum FactoryLumi2 {

    /// 创建 KernelCore 内核，并注册默认的 `ProjectProviding` 实现。
    ///
    /// - Returns: 已注册 `ProjectProviding` 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel() throws -> KernelCoreContainer {
        try makeKernel(projectProvider: DefaultProjectProviding())
    }

    /// 创建 KernelCore 内核，并注册自定义的 `ProjectProviding` 实现。
    ///
    /// - Parameter projectProvider: 由调用方提供的项目管理实现。
    /// - Returns: 已注册 `ProjectProviding` 的 KernelCore 容器。
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    public static func makeKernel(projectProvider: any ProjectProviding) throws -> KernelCoreContainer {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ProjectProviding).self, projectProvider)
        return kernel
    }
}
