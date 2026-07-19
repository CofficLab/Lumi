import Foundation

/// Lumi 插件协议
///
/// 所有插件必须实现此协议，以便向 LumiKernel 注册服务。
@MainActor
public protocol LumiPlugin: AnyObject {
    /// 插件唯一标识
    var id: String { get }

    /// 插件名称
    var name: String { get }

    /// 插件加载顺序
    ///
    /// 数值越小越先加载。用于控制插件间的依赖关系。
    /// - 核心插件：0-99
    /// - 基础服务：100-199
    /// - 功能插件：200-299
    /// - 可选插件：300+
    var order: Int { get }

    /// 注册服务到内核
    ///
    /// 在此方法中调用 `kernel.registerXxx()` 注册服务。
    /// - Parameter kernel: LumiKernel 实例
    func register(kernel: LumiKernel) throws

    /// 启动后回调（可选）
    ///
    /// 所有插件注册完成后调用，用于执行需要其他服务的初始化逻辑。
    /// - Parameter kernel: LumiKernel 实例
    func boot(kernel: LumiKernel) async throws
}
