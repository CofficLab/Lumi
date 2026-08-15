import Foundation

/// 超级插件协议
///
/// 插件（SuperPlugin）是「向内核注入能力 / 调用内核能力」的最小契约：
/// 内核通过 `id` 标识并管理插件；插件在 `onBoot(kernel:)` 中通过
/// `KernelCoreContainer` 注册 Provider、注册设置入口等，从而扩展内核。
///
/// 生命周期：
/// - `onBoot(kernel:)`：插件启动阶段，注册自己的能力（默认空实现）。
@MainActor
public protocol SuperPlugin: AnyObject {
    /// 插件唯一标识
    var id: String { get }

    /// 插件加载顺序（数值越小越先 `onBoot`）。默认 `200`。
    var order: Int { get }

    /// 插件启动：向内核注入能力。
    ///
    /// 在此方法中调用 `kernel.registerProvider(...)`、`kernel.registerPlugin(...)`
    /// 或解析其他 Provider（如 `kernel.resolveProvider(SettingViewProviding.self)`）
    /// 注册自己的贡献。默认空实现。
    func onBoot(kernel: KernelCoreContainer) throws
}

public extension SuperPlugin {
    var order: Int { 200 }

    func onBoot(kernel: KernelCoreContainer) throws {}
}
