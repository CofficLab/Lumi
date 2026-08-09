import LumiKernel
import GitPlugin
import SuperLogKit
import SwiftUI
import os

/// LumiFactory 门面
///
/// 提供应用启动的统一入口，封装内部实现细节。
/// 维护内核实例，负责完整的生命周期管理。
@MainActor
public enum LumiFactory: SuperLog {
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
    /// 创建 LumiKernel 实例，注册所有插件，并调用 bootstrap。
    /// - Returns: 初始化完成的内核实例
    /// - Throws: 初始化过程中的错误
    public static func createKernel(
        configuration: LumiHostConfiguration = .lumi
    ) async throws -> LumiKernel {
        if verbose {
            logger.info("\(t)创建新内核实例")
        }

        // 1. 创建内核
        let kernel = LumiKernel()

        // 2. 获取插件列表
        let plugins = try plugins(for: configuration)
        if verbose {
            logger.info("\(t)初始化 \(plugins.count) 个插件")
        }

        // 3. 初始化插件（存储插件实例）
        try await kernel.pluginManager.initializePlugins(plugins, kernel: kernel)

        // 宿主可显式启用白名单中的 opt-in 插件。这里不补齐任何依赖；
        // 白名单不足时仍由内核启动自检或插件生命周期明确报错。
        if !configuration.enabledPluginIDs.isEmpty {
            let overrides = Dictionary(
                uniqueKeysWithValues: configuration.enabledPluginIDs.map { ($0, true) }
            )
            kernel.pluginManager.applyPersistedPluginStates(overrides)
        }

        // 4. 订阅插件变更通知，当插件启用/禁用时重新注册 UI 贡献
        subscribeToPluginChanges(kernel: kernel)

        // 5. 启动内核（调用插件生命周期 + 服务校验 + UI/LLM/Tool 收集）
        try await kernel.startup()

        // 6. 保存到内核列表
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
    /// - Returns: 主内核实例
    /// - Throws: 初始化过程中的错误
    public static func createMainKernel(
        configuration: LumiHostConfiguration = .lumi
    ) async throws -> LumiKernel {
        if let existing = mainKernel {
            if verbose {
                logger.info("\(t)返回已存在的主内核")
            }
            return existing
        }
        return try await createKernel(configuration: configuration)
    }

    private static func plugins(for configuration: LumiHostConfiguration) throws -> [LumiPlugin] {
        guard let allowlist = configuration.pluginAllowlist else {
            return PluginService.plugins
        }

        let registeredIDs = Set(PluginService.plugins.map(\.id))
        let unknownIDs = allowlist.subtracting(registeredIDs)
        guard unknownIDs.isEmpty else {
            throw LumiHostConfigurationError.unknownPluginIDs(unknownIDs)
        }

        let enabledOutsideAllowlist = configuration.enabledPluginIDs.subtracting(allowlist)
        guard enabledOutsideAllowlist.isEmpty else {
            throw LumiHostConfigurationError.enabledPluginsOutsideAllowlist(enabledOutsideAllowlist)
        }

        return PluginService.plugins.filter { allowlist.contains($0.id) }
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
        configuration: LumiHostConfiguration = .lumi
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
