import Foundation
import KernelLumi
import SuperLogKit
import os

/// CAD Designer 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的后处理工作。
@MainActor
public struct CADDesignerOnReadyHook: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.cad-designer")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: KernelLumi) async throws {
        // CADDocumentStore 已经是单例,无需额外注册
        if Self.verbose {
            Self.logger.info("\(Self.t)CAD Designer 插件已就绪")
        }
    }
}
