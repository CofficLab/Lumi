import Foundation

/// 超级插件协议
///
/// 插件（SuperPlugin）是「向内核注入能力 / 调用内核能力」的最小契约：
/// 内核通过 `id` 标识并管理插件；具体能力（注册 Provider、调用其他
/// 功能）由插件在生命周期方法中通过 `KernelCoreContainer` 完成。
///
/// 当前只声明 `id` 属性；生命周期与注入机制后续在此基础上扩展。
@MainActor
public protocol SuperPlugin: AnyObject {
    /// 插件唯一标识
    var id: String { get }
}
