import Foundation
import LumiKernel
import SuperLogKit
import os

/// Storage 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的 Storage 服务注册,确保在 onReady 之前内核已持有 StorageProviding。
@MainActor
public struct StorageOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.storage")
    nonisolated static let verbose = false

    public let dataRootDirectory: URL

    public init(dataRootDirectory: URL) {
        self.dataRootDirectory = dataRootDirectory
    }

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        let storage = StorageService(dataRootDirectory: dataRootDirectory)
        kernel.registerStorage(storage)
        if Self.verbose {
            Self.logger.info("已注册 Storage 服务: \(self.dataRootDirectory.path)")
        }
    }
}
