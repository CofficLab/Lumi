import Foundation
import Testing
@testable import PluginLLMProviderMLX

/// 下载进度事件不应触发全量磁盘扫描。
///
/// ## 为什么要有这条测试
///
/// 底层下载器每写入 64KB 就回调一次进度（4GiB 模型约 65,536 次），
/// 而下载状态的完整求值原本包含「逐模型完成检查 + 整个缓存目录递归
/// 枚举」。这些操作全在主线程执行，逐次执行会把进度事件放大成持续的
/// 磁盘 I/O 风暴，表现为下载界面卡顿、进度滞后与其它界面响应变慢。
///
/// 正确行为：进度事件只更新速度、字节数与比例；已下载模型集合与缓存
/// 大小只在结构性变化（完成 / 删除 / 取消 / 显式刷新）时重算。
@MainActor
@Suite("MLX 下载进度不触发磁盘扫描", .serialized)
struct MLXDownloadProgressScanTests {

    /// 扫描桩：记录被调用的次数并返回固定快照。
    private final class ScanCounter {
        private(set) var callCount = 0
        var models: Set<String> = ["mlx-qwen/Qwen3-0.6B-4bit"]
        var size: Int64 = 4096

        func scan() -> MLXDownloadCacheIndex.Snapshot {
            callCount += 1
            return MLXDownloadCacheIndex.Snapshot(
                downloadedModelIDs: models,
                cacheSizeBytes: size
            )
        }
    }

    /// 注入临时目录，避免触碰本机真实数据目录。
    ///
    /// `MLXDownloadManager` 是进程级单例，模型根目录与运行时目录都必须
    /// 显式注入，否则测试进程里的目录守卫会直接终止进程。
    private func withInjectedDirectories(_ body: () -> Void) {
        let root = MLXProviderTestDoubles.makeTemporaryDirectory("download-scan")
        MLXModelPaths.configure(rootDirectory: root)
        MLXProviderRuntime.configure(settingsDirectory: root)
        defer {
            MLXProviderRuntime.reset()
            MLXModelPaths.configure(rootDirectory: root)
        }
        body()
    }

    @Test("下载状态被反复读取时只扫描一次")
    func repeatedStateReadsScanOnce() {
        withInjectedDirectories {
            let manager = MLXDownloadManager.shared
            let counter = ScanCounter()
            let original = manager.cacheScanner
            manager.cacheScanner = { counter.scan() }
            // 单例共享状态：先作废上一次用例留下的扫描快照。
            manager.invalidateCacheSnapshot()
            defer {
                manager.cacheScanner = original
                manager.invalidateCacheSnapshot()
            }

            // 首次读取触发一次扫描。
            _ = manager.downloadState
            let scansAfterFirst = counter.callCount

            // 后续读取命中缓存，不再扫描。
            for _ in 0..<50 {
                _ = manager.downloadState
            }

            #expect(scansAfterFirst == 1, "首次读取应扫描一次")
            #expect(
                counter.callCount == scansAfterFirst,
                "重复读取不应触发新的磁盘扫描，实际扫描 \(counter.callCount) 次"
            )
        }
    }

    @Test("显式刷新会重新扫描（磁盘可能已被外部改动）")
    func explicitRefreshRescans() {
        withInjectedDirectories {
            let manager = MLXDownloadManager.shared
            let counter = ScanCounter()
            let original = manager.cacheScanner
            manager.cacheScanner = { counter.scan() }
            // 单例共享状态：先作废上一次用例留下的扫描快照。
            manager.invalidateCacheSnapshot()
            defer {
                manager.cacheScanner = original
                manager.invalidateCacheSnapshot()
            }

            // 建立订阅：`refreshDownloadState` 只在有订阅者时才求值状态。
            let subscription = manager.downloadStatePublisher.sink { _ in }
            defer { subscription.cancel() }

            let scansAfterSubscribe = counter.callCount

            manager.refreshDownloadState()

            #expect(
                counter.callCount == scansAfterSubscribe + 1,
                "显式刷新应触发重新扫描"
            )
        }
    }

    @Test("扫描结果被缓存，状态里的模型集合与缓存大小一致")
    func stateUsesCachedSnapshot() {
        withInjectedDirectories {
            let manager = MLXDownloadManager.shared
            let counter = ScanCounter()
            let original = manager.cacheScanner
            manager.cacheScanner = { counter.scan() }
            // 单例共享状态：先作废上一次用例留下的扫描快照。
            manager.invalidateCacheSnapshot()
            defer {
                manager.cacheScanner = original
                manager.invalidateCacheSnapshot()
            }

            let state = manager.downloadState

            #expect(
                state.downloadedModelIDs == ["mlx-qwen/Qwen3-0.6B-4bit"],
                "状态应使用扫描桩返回的快照，实际 \(state.downloadedModelIDs)"
            )
            #expect(state.cacheSizeBytes == 4096)
        }
    }
}
