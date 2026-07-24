import Foundation
import LumiKernel
import SuperLogKit
import os

/// LegacyData 插件 OnBoot 阶段钩子
///
/// 在 boot 阶段定位 v4 旧数据目录并注册只读 `LegacyDataService`。
/// 注册在 onBoot 完成,确保消费插件(ConversationStorePlugin / MessageStorePlugin)
/// 在 onReady 时能通过 `kernel.legacyData` 取用。
@MainActor
public struct LegacyDataOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.legacy-data")
    nonisolated static let verbose = true

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        let v4Root = resolveV4DataRootDirectory(kernel: kernel)

        let service = LegacyDataService(v4DataRootDirectory: v4Root)
        kernel.registerLegacyDataService(service)

        if Self.verbose {
            if let v4Root {
                Self.logger.info("已注册 LegacyData 服务,v4 目录: \(v4Root.path)")
            } else {
                Self.logger.info("已注册 LegacyData 服务(未发现 v4 旧数据,全新安装)")
            }
        }
    }

    /// 定位 v4 数据根目录
    ///
    /// 策略:当前版本数据目录形如 `<AppSupport>/<bundleID>/db_production_v5`,
    /// 取其父目录,查找兄弟目录 `db_production_v4`。Release 构建找 production,
    /// Debug 找 debug(与版本化目录命名一致)。
    private func resolveV4DataRootDirectory(kernel: LumiKernel) -> URL? {
        guard let currentRoot = kernel.storage?.dataRootDirectory else { return nil }
        let parent = currentRoot.deletingLastPathComponent()

        #if DEBUG
        let candidates = ["db_production_v4", "db_debug_v4"]
        #else
        let candidates = ["db_production_v4"]
        #endif

        let fileManager = FileManager.default
        for name in candidates {
            let dir = parent.appendingPathComponent(name, isDirectory: true)
            if fileManager.fileExists(atPath: dir.path) {
                return dir
            }
        }
        return nil
    }
}
