import Foundation
import LumiKernel
import SuperLogKit
import os

/// CAD Designer 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的初始化和数据目录设置。
@MainActor
public struct CADDesignerOnBootHook: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.cad-designer")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        // 设置数据目录
        if let storage = kernel.storage {
            CADDesignerRuntimeBridge.dataRootDirectory = storage.dataRootDirectory
            CADDesignerRuntimeBridge.pluginSubdirectory = storage.pluginDataDirectory(for: "CADDesignerPlugin")
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)CAD Designer 插件已初始化")
        }
    }
}
