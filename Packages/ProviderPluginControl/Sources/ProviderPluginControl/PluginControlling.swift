import Foundation
import KernelCore

@MainActor
public protocol PluginControlling: AnyObject {
    var lastErrorDescription: String? { get }
    func enablePlugin(id: String) async -> Bool
    func disablePlugin(id: String) async -> Bool
    func isEnabled(id: String) -> Bool
}

/// 直接驱动 `KernelCoreContainer` 的插件控制实现。
///
/// 旧骨架只维护自己的内存 Set，UI 看似启停成功但 Kernel 中的插件和贡献没有
/// 变化。该实现把控制动作连接到真实生命周期，并保留最近一次错误供设置页展示。
@MainActor
public final class DefaultPluginControlling: PluginControlling {
    public private(set) var lastErrorDescription: String?
    private weak var kernel: KernelCoreContainer?

    public init(kernel: KernelCoreContainer? = nil) {
        self.kernel = kernel
    }

    public func attach(kernel: KernelCoreContainer) {
        self.kernel = kernel
    }

    public func enablePlugin(id: String) async -> Bool {
        guard let kernel else {
            lastErrorDescription = "Kernel is not attached"
            return false
        }
        do {
            try await kernel.enablePlugin(id: id)
            lastErrorDescription = nil
            return true
        } catch {
            lastErrorDescription = error.localizedDescription
            return false
        }
    }

    public func disablePlugin(id: String) async -> Bool {
        guard let kernel else {
            lastErrorDescription = "Kernel is not attached"
            return false
        }
        do {
            try await kernel.disablePlugin(id: id)
            lastErrorDescription = nil
            return true
        } catch {
            lastErrorDescription = error.localizedDescription
            return false
        }
    }

    public func isEnabled(id: String) -> Bool {
        kernel?.isPluginEnabled(id: id) ?? false
    }
}
