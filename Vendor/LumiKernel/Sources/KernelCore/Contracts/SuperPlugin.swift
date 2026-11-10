import Foundation

/// 超级插件协议
///
/// 插件（SuperPlugin）是「向内核注入能力 / 调用内核能力」的最小契约：
/// 内核通过 `id` 标识并管理插件；插件在 `onBoot(kernel:)` 中通过
/// `KernelCoreContainer` 注册 Provider、注册设置入口等，从而扩展内核。
///
/// 生命周期：
/// - `onBoot(kernel:)`：插件启动阶段，注册自己的能力（默认空实现）。
/// - `onReady(kernel:)`：全部插件完成 Boot 后执行，可安全解析依赖插件贡献。
/// - `onShutdown(kernel:)`：插件卸载或内核停止时逆序执行，撤回外部贡献。
@MainActor
public protocol SuperPlugin: AnyObject {
    /// 插件唯一标识
    var id: String { get }

    /// 插件加载顺序（数值越小越先 `onBoot`）。默认 `200`。
    var order: Int { get }

    /// 必须先于当前插件启动的插件 id。默认无依赖。
    var dependencies: [String] { get }

    /// 用于插件管理、诊断和权限展示的稳定元数据。
    var metadata: PluginMetadata { get }

    /// 插件注册到 Kernel 后调用，无论插件当前是否启用。
    ///
    /// 这里只应注册不依赖插件运行状态的目录型贡献，例如提示词和元数据。
    func onRegister(kernel: KernelCoreContainer) throws

    /// 插件启动：向内核注入能力。
    ///
    /// 在此方法中调用 `kernel.registerProvider(...)`、`kernel.registerPlugin(...)`
    /// 或解析其他 Provider（如 `kernel.resolveProvider(SettingViewProviding.self)`）
    /// 注册自己的贡献。默认空实现。
    func onBoot(kernel: KernelCoreContainer) throws

    /// 全部插件完成 `onBoot` 后调用。
    func onReady(kernel: KernelCoreContainer) throws

    /// 卸载时调用。插件应在这里撤回注册到共享 Provider 中的贡献。
    func onShutdown(kernel: KernelCoreContainer) throws

    /// 插件从 Kernel 注销前调用，用于撤回 `onRegister` 的目录型贡献。
    func onUnregister(kernel: KernelCoreContainer) throws

    /// 运行时启用。插件可在这里恢复被禁用时停止的监听器与贡献。
    func onEnable(kernel: KernelCoreContainer) async throws

    /// 运行时禁用。Kernel 会在回调成功后自动撤回该插件登记的贡献。
    func onDisable(kernel: KernelCoreContainer) async throws
}

public extension SuperPlugin {
    var order: Int { 200 }

    var dependencies: [String] { [] }

    func onRegister(kernel: KernelCoreContainer) throws {}

    func onBoot(kernel: KernelCoreContainer) throws {}

    func onReady(kernel: KernelCoreContainer) throws {}

    func onShutdown(kernel: KernelCoreContainer) throws {}

    func onUnregister(kernel: KernelCoreContainer) throws {}

    func onEnable(kernel: KernelCoreContainer) async throws {}

    func onDisable(kernel: KernelCoreContainer) async throws {}
}

/// 需要异步 Boot / Ready / Shutdown 的插件使用该协议。
///
/// 同步 `SuperPlugin` 保留为轻量插件和现有迁移代码的兼容入口；宿主必须通过
/// `startAsync(plugins:)` 启动实现本协议的插件，避免异步初始化被静默跳过。
@MainActor
public protocol AsyncSuperPlugin: SuperPlugin {
    func onBootAsync(kernel: KernelCoreContainer) async throws
    func onReadyAsync(kernel: KernelCoreContainer) async throws
    func onShutdownAsync(kernel: KernelCoreContainer) async throws
}

public extension AsyncSuperPlugin {
    func onBootAsync(kernel: KernelCoreContainer) async throws {
        try onBoot(kernel: kernel)
    }

    func onReadyAsync(kernel: KernelCoreContainer) async throws {
        try onReady(kernel: kernel)
    }

    func onShutdownAsync(kernel: KernelCoreContainer) async throws {
        try onShutdown(kernel: kernel)
    }
}
