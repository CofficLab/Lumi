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

    @Test("下载状态包含已下载模型的实际磁盘占用")
    func stateExposesDownloadedModelSizes() {
        withInjectedDirectories {
            let manager = MLXDownloadManager.shared
            let original = manager.cacheScanner
            manager.cacheScanner = {
                MLXDownloadCacheIndex.Snapshot(
                    downloadedModelIDs: ["mlx-qwen/Qwen3-0.6B-4bit"],
                    downloadedModelSizesBytes: ["mlx-qwen/Qwen3-0.6B-4bit": 351_386_061],
                    cacheSizeBytes: 351_386_061
                )
            }
            manager.invalidateCacheSnapshot()
            defer {
                manager.cacheScanner = original
                manager.invalidateCacheSnapshot()
            }

            #expect(
                manager.downloadState.downloadedModelSizesBytes["mlx-qwen/Qwen3-0.6B-4bit"]
                    == 351_386_061
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

    @Test("进度事件只读缓存，反复回调不触发磁盘扫描（#1125）")
    func progressEventsDoNotRescan() {
        withInjectedDirectories {
            let manager = MLXDownloadManager.shared
            let counter = ScanCounter()
            let original = manager.cacheScanner
            manager.cacheScanner = { counter.scan() }
            manager.invalidateCacheSnapshot()
            defer {
                manager.cacheScanner = original
                manager.activeOperationID = nil
                manager.invalidateCacheSnapshot()
            }

            // 建立订阅：发布状态只在有订阅者时才求值（单例的 subject 可能已存在）。
            let subscription = manager.downloadStatePublisher.sink { _ in }
            defer { subscription.cancel() }
            // 显式求值一次建立缓存快照（上面已作废缓存）。
            _ = manager.downloadState
            let baseline = counter.callCount
            #expect(baseline == 1, "建立缓存时应扫描一次")

            // 模拟底层每 64KB 一次的进度回调：同一 operationID 反复 publishProgress。
            let operationID = UUID()
            manager.activeOperationID = operationID
            let totalBytes: Int64 = 4 * 1024 * 1024 * 1024
            for tick in 0..<200 {
                manager.publishProgress(
                    operationID: operationID,
                    completedBytes: Int64(tick) * 64 * 1024,
                    currentBytes: 0,
                    completedFiles: 0,
                    totalFiles: 1,
                    totalBytes: totalBytes,
                    speed: 1_000_000
                )
            }

            #expect(
                counter.callCount == baseline,
                "进度事件不应触发新的磁盘扫描，实际扫描 \(counter.callCount) 次"
            )
        }
    }

    @Test("进度事件仍然更新字节数与比例（#1125）")
    func progressEventsStillUpdateBytesAndFraction() {
        withInjectedDirectories {
            let manager = MLXDownloadManager.shared
            let counter = ScanCounter()
            let original = manager.cacheScanner
            manager.cacheScanner = { counter.scan() }
            manager.invalidateCacheSnapshot()
            defer {
                manager.cacheScanner = original
                manager.activeOperationID = nil
                manager.invalidateCacheSnapshot()
            }
            let subscription = manager.downloadStatePublisher.sink { _ in }
            defer { subscription.cancel() }

            let operationID = UUID()
            manager.activeOperationID = operationID
            manager.publishProgress(
                operationID: operationID,
                completedBytes: 1024,
                currentBytes: 0,
                completedFiles: 0,
                totalFiles: 1,
                totalBytes: 4096,
                speed: 2048
            )

            #expect(manager.progress.downloadedBytes == 1024)
            #expect(manager.progress.totalBytes == 4096)
            #expect(manager.progress.speed == 2048)
            #expect(manager.progress.fractionCompleted > 0)
            // 进度发布走缓存，不额外扫描。
            #expect(counter.callCount == 1)
        }
    }

    @Test("进度事件之后显式刷新仍会重新扫描（缓存不被永久冻结）")
    func explicitRefreshAfterProgressRescans() {
        withInjectedDirectories {
            let manager = MLXDownloadManager.shared
            let counter = ScanCounter()
            let original = manager.cacheScanner
            manager.cacheScanner = { counter.scan() }
            manager.invalidateCacheSnapshot()
            defer {
                manager.cacheScanner = original
                manager.activeOperationID = nil
                manager.invalidateCacheSnapshot()
            }
            let subscription = manager.downloadStatePublisher.sink { _ in }
            defer { subscription.cancel() }

            let operationID = UUID()
            manager.activeOperationID = operationID
            manager.publishProgress(
                operationID: operationID,
                completedBytes: 64 * 1024,
                currentBytes: 0,
                completedFiles: 0,
                totalFiles: 1,
                totalBytes: 4096,
                speed: nil
            )
            let scansAfterProgress = counter.callCount

            manager.refreshDownloadState()

            #expect(
                counter.callCount == scansAfterProgress + 1,
                "结构性刷新应重新扫描，进度缓存不得永久冻结"
            )
        }
    }
}
