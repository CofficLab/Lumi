import Foundation
import Testing
@testable import PluginLLMProviderMLX

/// 下载缓存的磁盘扫描必须被缓存，而不是每次进度事件都重扫。
///
/// ## 为什么要有这条测试
///
/// 底层下载器每写入 64KB 就回调一次进度（4GiB 模型约 65,536 次），
/// 而下载状态的完整求值包含「逐模型完成检查 + 整个缓存目录递归枚举」。
/// 这些操作全在主线程，逐次执行会把进度事件放大成磁盘 I/O 风暴。
///
/// 正确行为：扫描结果只在结构性变化时重算，进度事件只读缓存。
@MainActor
@Suite("MLX 下载缓存扫描索引")
struct MLXDownloadCacheIndexTests {

    @Test("首次读取才扫描一次")
    func firstReadScansOnce() {
        let index = MLXDownloadCacheIndex()
        var scanCount = 0

        let snapshot = index.snapshot {
            scanCount += 1
            return MLXDownloadCacheIndex.Snapshot(
                downloadedModelIDs: ["mlx-qwen/Qwen3-0.6B-4bit"],
                cacheSizeBytes: 1024
            )
        }

        #expect(scanCount == 1)
        #expect(snapshot.downloadedModelIDs == ["mlx-qwen/Qwen3-0.6B-4bit"])
        #expect(snapshot.cacheSizeBytes == 1024)
        #expect(index.scanCount == 1)
    }

    @Test("连续读取不再扫描")
    func repeatedReadsDoNotRescan() {
        let index = MLXDownloadCacheIndex()
        var scanCount = 0

        for _ in 0..<100 {
            _ = index.snapshot {
                scanCount += 1
                return MLXDownloadCacheIndex.Snapshot(downloadedModelIDs: [], cacheSizeBytes: 0)
            }
        }

        #expect(scanCount == 1, "缓存命中时不应重复扫描磁盘")
        #expect(index.scanCount == 1)
    }

    @Test("作废后下次读取重新扫描")
    func invalidateForcesRescan() {
        let index = MLXDownloadCacheIndex()
        var scanCount = 0

        func read() -> MLXDownloadCacheIndex.Snapshot {
            index.snapshot {
                scanCount += 1
                return MLXDownloadCacheIndex.Snapshot(
                    downloadedModelIDs: ["model-\(scanCount)"],
                    cacheSizeBytes: Int64(scanCount)
                )
            }
        }

        #expect(read().cacheSizeBytes == 1)
        #expect(read().cacheSizeBytes == 1)

        index.invalidate()

        #expect(read().cacheSizeBytes == 2, "作废后必须重新扫描")
        #expect(index.scanCount == 2)
    }

    @Test("作废后读到的是最新磁盘状态")
    func invalidateReflectsLatestDiskState() {
        let index = MLXDownloadCacheIndex()
        var diskModels: Set<String> = []
        var diskSize: Int64 = 0

        func read() -> MLXDownloadCacheIndex.Snapshot {
            index.snapshot {
                MLXDownloadCacheIndex.Snapshot(
                    downloadedModelIDs: diskModels,
                    cacheSizeBytes: diskSize
                )
            }
        }

        #expect(read().downloadedModelIDs.isEmpty)

        // 下载完成：模型写入缓存目录。
        diskModels = ["mlx-qwen/Qwen3-0.6B-4bit"]
        diskSize = 4096
        index.invalidate()

        #expect(read().downloadedModelIDs == ["mlx-qwen/Qwen3-0.6B-4bit"])
        #expect(read().cacheSizeBytes == 4096)
    }
}
