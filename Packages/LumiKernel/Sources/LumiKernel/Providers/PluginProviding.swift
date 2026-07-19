import Foundation
import SwiftUI

// MARK: - Plugin Capability Protocol

/// 插件能力协议
///
/// 定义 LumiCore 需要的插件管理功能，由具体布局插件实现。
/// 负责管理所有插件的注册、启动、查询和排序。
@MainActor
public protocol PluginProviding: ObservableObject {
    /// 所有已注册的插件（按 order 排序）
    var allPlugins: [LumiPlugin] { get }

    /// 按 ID 查询插件
    func plugin(id: String) -> LumiPlugin?

    /// 按类型查询插件
    func plugin<T: LumiPlugin>(ofType type: T.Type) -> T?

    /// 注册插件（内部使用，调用插件的 register 方法）
    func registerPlugin(_ plugin: LumiPlugin) throws

    /// 批量注册插件
    func registerPlugins(_ plugins: [LumiPlugin]) throws

    /// 启动所有插件
    func bootstrapPlugins() async throws

    /// 注册所有插件的 UI 贡献项
    ///
    /// - Parameter kernel: LumiKernel 实例，用于将 UI 贡献注册到对应服务
    func registerPluginUIContributions(in kernel: LumiKernel)
}
