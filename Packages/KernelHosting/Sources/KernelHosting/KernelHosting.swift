import Foundation
import KernelLumi
import SuperLogKit
import os

/// 内核生命周期宿主
///
/// 维护 `KernelLumi` 实例注册表，提供创建 / 销毁 / 主内核访问。
/// 这一层是**平台中性**的（同时编译到 macOS 与 iOS）：它只依赖 `KernelLumi`
/// 与日志，不涉及窗口 / 工具栏 / 菜单栏等任何 chrome。
///
/// macOS 宿主 `FactoryCore` 与各 App 专属的 iOS Factory 都复用
/// 这一份内核生命周期实现，避免双宿主之间漂移。
///
/// 插件列表由宿主在编译期确定并显式传入，本类型不做任何 ID 过滤或白名单补齐。
@MainActor
public enum KernelHosting: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "kernel-hosting")
    nonisolated public static let emoji = "⚙️"
    nonisolated static let verbose = false

    // MARK: - Kernel Registry

    /// 已创建的内核实例
    public private(set) static var kernels: [KernelLumi] = []

    /// 主内核（第一个创建的）
    public static var mainKernel: KernelLumi? {
        kernels.first
    }

    // MARK: - Kernel Factory

    /// 创建并初始化新内核
    ///
    /// 创建 `KernelLumi` 实例，注册 `plugins`，并调用 bootstrap。
    /// - Parameters:
    ///   - plugins: 宿主在编译期确定的最终插件列表（顺序敏感）。
    ///   - enabledPluginIDs: 希望默认启用的 opt-in 插件 ID（`plugins.map(\.id)` 的子集）。
    /// - Returns: 初始化完成的内核实例。
    /// - Throws: 初始化过程中的错误。
    public static func createKernel(
        plugins: [any LumiPlugin],
        enabledPluginIDs: Set<String> = [],
        requiresAllCoreServices: Bool = true
    ) async throws -> KernelLumi {
        if verbose {
            logger.info("\(t)创建新内核实例")
        }

        // 1. 创建内核
        let kernel = KernelLumi()

        // 2. 初始化插件（存储插件实例）。插件列表由宿主在编译期确定，
        //    这里不再做任何 ID 过滤或白名单补齐。
        if verbose {
            logger.info("\(t)初始化 \(plugins.count) 个插件")
        }
        try await kernel.pluginManager.initializePlugins(plugins, kernel: kernel)

        // 宿主可显式启用 opt-in 插件。这里不补齐任何依赖；
        // 插件集合不足时仍由内核启动自检或插件生命周期明确报错。
        if !enabledPluginIDs.isEmpty {
            let overrides = Dictionary(
                uniqueKeysWithValues: enabledPluginIDs.map { ($0, true) }
            )
            kernel.pluginManager.applyPersistedPluginStates(overrides)
        }

        // 3. 订阅插件变更通知，当插件启用/禁用时重新注册 UI 贡献
        subscribeToPluginChanges(kernel: kernel)

        // 是否强制要求全部核心服务（macOS 宿主默认 true；单用途 iOS app 可 false）
        kernel.requiresAllCoreServices = requiresAllCoreServices

        // 4. 启动内核（调用插件生命周期 + 服务校验 + UI/LLM/Tool 收集）
        try await kernel.startup()

        // 5. 保存到内核列表
        kernels.append(kernel)

        if verbose {
            Self.logger.info("\(Self.t)内核创建完成，已注册 \(kernel.pluginManager.allPlugins.count) 个插件")
        }
        return kernel
    }

    /// 创建主内核（如果尚未创建）
    ///
    /// 通常在应用启动时调用一次。
    /// - Parameters:
    ///   - plugins: 宿主在编译期确定的最终插件列表（顺序敏感）。
    ///   - enabledPluginIDs: 希望默认启用的 opt-in 插件 ID。
    /// - Returns: 主内核实例。
    /// - Throws: 初始化过程中的错误。
    public static func createMainKernel(
        plugins: [any LumiPlugin],
        enabledPluginIDs: Set<String> = []
    ) async throws -> KernelLumi {
        if let existing = mainKernel {
            if verbose {
                logger.info("\(t)返回已存在的主内核")
            }
            return existing
        }
        return try await createKernel(plugins: plugins, enabledPluginIDs: enabledPluginIDs)
    }

    /// 订阅 `.lumiEnabledPluginsDidChange` 通知，
    /// 在运行期插件启用/禁用时全量重建插件贡献(UI + LLM Provider)。
    private static func subscribeToPluginChanges(kernel: KernelLumi) {
        NotificationCenter.default.addObserver(
            forName: .lumiEnabledPluginsDidChange,
            object: nil,
            queue: .main
        ) { [weak kernel] _ in
            guard let kernel else { return }
            // 全量重建:禁用插件的贡献即时撤回,启用插件的贡献即时加入。
            kernel.pluginManager.rebuildAllContributions(in: kernel)
            kernel.refreshMenuBarPresentation()
        }
    }

    /// 销毁指定内核
    ///
    /// - Parameter kernel: 要销毁的内核
    public static func destroyKernel(_ kernel: KernelLumi) {
        kernels.removeAll { $0 === kernel }
        if verbose {
            logger.info("\(t)内核已销毁，剩余 \(kernels.count) 个")
        }
    }

    /// 销毁所有内核（用于测试或重置）
    public static func destroyAllKernels() {
        kernels.removeAll()
        if verbose {
            logger.info("\(t)所有内核已销毁")
        }
    }
}
