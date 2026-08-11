import Foundation
import LumiKernel
import os

/// PromoDesigner 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑。
/// 当前为空实现，预留结构以备后续扩展（例如延迟初始化、桥接设置等）。
@MainActor
public struct PromoDesignerOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.promo-designer")

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) async throws {}
}
