import Foundation
import LumiKernel
import SuperLogKit
import os

/// Storage 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑
@MainActor
public struct StorageOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.storage")
    nonisolated static let verbose = false

    public let dataRootDirectory: URL

    public init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory
    }

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        let storage = StorageService(dataRootDirectory: dataRootDirectory)
        kernel.registerStorage(storage)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Storage 服务: \(self.dataRootDirectory.path)")
        }
    }
}
