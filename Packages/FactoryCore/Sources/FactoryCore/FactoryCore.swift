import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// FactoryCore 门面
///
/// 提供应用启动的统一入口，封装内部实现细节。
/// 维护内核实例，负责完整的生命周期管理。
///
/// `FactoryCore` **不依赖任何具体插件**。插件列表由宿主 Factory
/// （`FactoryLumi` / `FactoryBookletMaker`）在编译期确定，通过
/// `FactoryConfiguration` 显式传入 `createKernel`。这让每个应用 Target
/// 只链接自己需要的插件包，编译器能裁掉其余插件依赖。
@MainActor
public enum FactoryCore: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "factory")
    nonisolated public static let emoji = "🏭"
    nonisolated static let verbose = false

    // MARK: - Kernel Registry

    /// 已创建的内核实例
    public private(set) static var kernels: [LumiKernel] = []

    /// 主内核（第一个创建的）
    public static var mainKernel: LumiKernel? {
        kernels.first
    }

    // MARK: - Kernel Factory

    /// 创建并初始化新内核
    ///
    /// 创建 LumiKernel 实例，注册 `configuration.plugins`，并调用 bootstrap。
    /// - Parameter configuration: 宿主 Factory 组装好的最终配置。
    /// - Returns: 初始化完成的内核实例
    /// - Throws: 初始化过程中的错误
    public static func createKernel(
        configuration: FactoryConfiguration
    ) async throws -> LumiKernel {
        if verbose {
            logger.info("\(t)创建新内核实例")
        }

        // 1. 创建内核
        let kernel = LumiKernel()

        // 2. 初始化插件（存储插件实例）。插件列表由宿主在编译期确定，
        //    Core 不再做任何 ID 过滤或白名单补齐。
        if verbose {
            logger.info("\(t)初始化 \(configuration.plugins.count) 个插件")
        }
        try await kernel.pluginManager.initializePlugins(configuration.plugins, kernel: kernel)

        // 宿主可显式启用 opt-in 插件。这里不补齐任何依赖；
        // 插件集合不足时仍由内核启动自检或插件生命周期明确报错。
        if !configuration.enabledPluginIDs.isEmpty {
            let overrides = Dictionary(
                uniqueKeysWithValues: configuration.enabledPluginIDs.map { ($0, true) }
            )
            kernel.pluginManager.applyPersistedPluginStates(overrides)
        }

        // 3. 订阅插件变更通知，当插件启用/禁用时重新注册 UI 贡献
        subscribeToPluginChanges(kernel: kernel)

        // 4. 启动内核（调用插件生命周期 + 服务校验 + UI/LLM/Tool 收集）
        try await kernel.startup()

        // 5. 保存到内核列表
        kernels.append(kernel)

        if verbose {
            Self.logger.info("\(Self.t)内核创建完成，已注册 \(kernel.pluginManager.allPlugins.count) 个插件")
        }
        return kernel
    }

    /// 订阅 `.lumiEnabledPluginsDidChange` 通知，
    /// 在运行期插件启用/禁用时全量重建插件贡献(UI + LLM Provider)。
    private static func subscribeToPluginChanges(kernel: LumiKernel) {
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

    /// 创建主内核（如果尚未创建）
    ///
    /// 通常在应用启动时调用一次。
    /// - Parameter configuration: 宿主 Factory 组装好的最终配置。
    /// - Returns: 主内核实例
    /// - Throws: 初始化过程中的错误
    public static func createMainKernel(
        configuration: FactoryConfiguration
    ) async throws -> LumiKernel {
        if let existing = mainKernel {
            if verbose {
                logger.info("\(t)返回已存在的主内核")
            }
            return existing
        }
        return try await createKernel(configuration: configuration)
    }

    /// 销毁指定内核
    ///
    /// - Parameter kernel: 要销毁的内核
    public static func destroyKernel(_ kernel: LumiKernel) {
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

    // MARK: - Window Factory

    /// 创建主窗口视图
    public static func makeMainWindow(
        configuration: FactoryConfiguration
    ) -> some View {
        WindowMain(configuration: configuration)
    }

    /// 创建设置窗口视图
    public static func makeSettingsWindow() -> some View {
        WindowSettings()
    }

    // MARK: - Commands Factory

    /// 创建应用命令菜单
    public static func makeCommands() -> some Commands {
        AppCommands()
    }
}
