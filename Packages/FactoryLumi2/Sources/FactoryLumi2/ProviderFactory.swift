import Foundation
import ProviderNetwork
import ProviderProject
import ProviderRootView
import ProviderToast
import ProviderToolbar

/// 产出各种 Provider 实现的工厂协议。
///
/// 集中管理 Provider 的构造逻辑；`KernelFactory.makeKernel` 直接调用它
/// 产出各 Provider 并注册进 KernelCore。宿主可实现该协议覆盖
/// 个别 Provider 的产出逻辑。
@MainActor
public protocol ProviderFactory {
    /// 产出 `ProjectProviding` 实现。
    func makeProjectProvider() -> any ProjectProviding

    /// 产出 `ToastProviding` 实现。
    func makeToastProvider() -> any ToastProviding

    /// 产出 `NetworkProviding` 实现。
    func makeNetworkProvider() -> any NetworkProviding

    /// 产出 `ToolbarProviding` 实现。
    func makeToolbarProvider() -> any ToolbarProviding

    /// 产出 `RootViewProviding` 实现。
    func makeRootViewProvider() -> any RootViewProviding
}

/// 默认 `ProviderFactory` 实现：产出各 Provider 的默认实现。
@MainActor
public struct DefaultProviderFactory: ProviderFactory {
    public init() {}

    /// 产出 `ProjectProviding` 实现（默认内存实现）。
    public func makeProjectProvider() -> any ProjectProviding {
        DefaultProjectProviding()
    }

    /// 产出 `ToastProviding` 实现（默认 no-op 实现）。
    public func makeToastProvider() -> any ToastProviding {
        DefaultToastProviding()
    }

    /// 产出 `NetworkProviding` 实现（默认 URLSession 实现）。
    public func makeNetworkProvider() -> any NetworkProviding {
        DefaultNetworkProviding()
    }

    /// 产出 `ToolbarProviding` 实现（默认按 placement 渲染的工具栏）。
    public func makeToolbarProvider() -> any ToolbarProviding {
        DefaultToolbarProviding()
    }

    /// 产出 `RootViewProviding` 实现（默认「工具栏 + 内容区」根布局）。
    public func makeRootViewProvider() -> any RootViewProviding {
        DefaultRootViewProviding()
    }
}
