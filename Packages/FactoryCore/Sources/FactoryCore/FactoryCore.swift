import KernelHosting
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

    // MARK: - Kernel Registry (delegates to KernelHosting)

    /// 已创建的内核实例
    public static var kernels: [LumiKernel] { KernelHosting.kernels }

    /// 主内核（第一个创建的）
    public static var mainKernel: LumiKernel? { KernelHosting.mainKernel }

    // MARK: - Kernel Factory (delegates to KernelHosting)

    /// 创建并初始化新内核
    ///
    /// 创建 LumiKernel 实例，注册 `configuration.plugins`，并调用 bootstrap。
    /// 实际生命周期由平台中性的 `KernelHosting` 承载，本门面仅负责解包配置，
    /// 让 macOS 现有调用方签名保持不变。
    /// - Parameter configuration: 宿主 Factory 组装好的最终配置。
    /// - Returns: 初始化完成的内核实例
    /// - Throws: 初始化过程中的错误
    public static func createKernel(
        configuration: FactoryConfiguration
    ) async throws -> LumiKernel {
        try await KernelHosting.createKernel(
            plugins: configuration.plugins,
            enabledPluginIDs: configuration.enabledPluginIDs
        )
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
        try await KernelHosting.createMainKernel(
            plugins: configuration.plugins,
            enabledPluginIDs: configuration.enabledPluginIDs
        )
    }

    /// 销毁指定内核
    ///
    /// - Parameter kernel: 要销毁的内核
    public static func destroyKernel(_ kernel: LumiKernel) {
        KernelHosting.destroyKernel(kernel)
    }

    /// 销毁所有内核（用于测试或重置）
    public static func destroyAllKernels() {
        KernelHosting.destroyAllKernels()
    }

    // MARK: - Window Factory

    /// 创建主窗口视图
    public static func makeMainWindow(
        configuration: FactoryConfiguration
    ) -> some View {
        WindowMain(configuration: configuration)
    }

    /// 创建使用宿主自定义启动页面的主窗口视图。
    ///
    /// 未使用此重载时，FactoryCore 会显示当前宿主 App 的应用图标。
    public static func makeMainWindow<LoadingContent: View>(
        configuration: FactoryConfiguration,
        @ViewBuilder loadingView: () -> LoadingContent
    ) -> some View {
        WindowMain(
            configuration: configuration,
            loadingView: AnyView(loadingView())
        )
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
