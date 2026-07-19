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

// MARK: - Default Implementation

extension LumiPlugin {
    public func boot(kernel: LumiKernel) async throws {
        // 默认空实现，插件可选择覆盖
    }
}