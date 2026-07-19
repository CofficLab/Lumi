import LumiKernel
import StoragePlugin
import SuperLogKit
import SwiftUI
import os

/// LumiFactory 门面
///
/// 提供应用启动的统一入口，封装内部实现细节。
/// 维护插件列表和内核实例，负责完整的生命周期管理。
@MainActor
public enum LumiFactory: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "factory")
    nonisolated public static let emoji = "🏭"

    // MARK: - Plugin Registry

    /// 插件列表
    ///
    /// 在应用启动前配置，LumiKernel 会按顺序注册这些插件。
    public private(set) static var plugins: [LumiPlugin] = []

    /// 注册插件
    public static func registerPlugin(_ plugin: LumiPlugin) {
        plugins.append(plugin)
    }

    /// 批量注册插件
    public static func registerPlugins(_ plugins: [LumiPlugin]) {
        self.plugins.append(contentsOf: plugins)
    }

    /// 清空插件列表（用于测试）
    public static func resetPlugins() {
        plugins.removeAll()
    }

    // MARK: - Built-in Plugins

    /// 注册内置插件
    ///
    /// 自动注册 LumiFactory 内置的插件（如 StoragePlugin）。
    /// 在 createKernel 时自动调用，避免重复注册。
    public static func registerBuiltInPlugins() {
        // 注册 StoragePlugin（如果尚未注册）
        let storagePluginId = "com.coffic.lumi.plugin.storage"
        if plugins.contains(where: { $0.id == storagePluginId }) {
            return
        }

        do {
            let storagePlugin = try StoragePlugin()
            registerPlugin(storagePlugin)
            logger.info("\(t)已注册内置插件: \(storagePlugin.name)")
        } catch {
            logger.error("\(t)注册 StoragePlugin 失败: \(error.localizedDescription)")
        }
    }

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
    /// 创建 LumiKernel 实例，自动注册内置插件，注册所有插件，并调用 bootstrap。
    /// - Returns: 初始化完成的内核实例
    /// - Throws: 初始化过程中的错误
    public static func createKernel() async throws -> LumiKernel {
        logger.info("\(t)创建新内核实例")

        // 1. 注册内置插件（确保至少有 StoragePlugin）
        registerBuiltInPlugins()

        // 2. 创建内核
        let kernel = LumiKernel()

        // 3. 注册插件
        logger.info("\(t)注册 \(plugins.count) 个插件")
        try kernel.registerPlugins(plugins)

        // 4. 启动插件
        try await kernel.bootstrapPlugins()

        // 5. 保存到内核列表
        kernels.append(kernel)

        logger.info("\(t)内核创建完成，已注册 \(kernel.allPlugins.count) 个插件")
        return kernel
    }

    /// 创建主内核（如果尚未创建）
    ///
    /// 通常在应用启动时调用一次。
    /// - Returns: 主内核实例
    /// - Throws: 初始化过程中的错误
    public static func createMainKernel() async throws -> LumiKernel {
        if let existing = mainKernel {
            logger.info("\(t)返回已存在的主内核")
            return existing
        }
        return try await createKernel()
    }

    /// 销毁指定内核
    ///
    /// - Parameter kernel: 要销毁的内核
    public static func destroyKernel(_ kernel: LumiKernel) {
        kernels.removeAll { $0 === kernel }
        logger.info("\(t)内核已销毁，剩余 \(kernels.count) 个")
    }

    /// 销毁所有内核（用于测试或重置）
    public static func destroyAllKernels() {
        kernels.removeAll()
        logger.info("\(t)所有内核已销毁")
    }

    // MARK: - Window Factory

    /// 创建主窗口视图
    public static func makeMainWindow() -> some View {
        WindowMain()
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