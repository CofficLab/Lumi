import CoreGraphics
import Testing
@testable import KitMarkdown

/// `HorizontalScrollView` 高度测量缓存（P1 修复）的契约测试。
///
/// 背景（docs/ui-performance-audit-2026-08.md P1）：流式输出期间
/// `updateNSView` 每帧被调用，旧实现无条件清空 fittingSize 缓存，
/// 导致每 16ms 对整段代码块重跑 `NSHostingView.fittingSize`。
/// 修复后的契约：仅当内容指纹或宽度分桶变化时才允许重新测量。
struct HorizontalFittingSizeCacheTests {

    // MARK: - 宽度分桶

    @Test func bucketedWidthQuantizesTo16PointSteps() {
        #expect(HorizontalFittingSizeCache<String>.bucketedWidth(for: 0) == 0)
        #expect(HorizontalFittingSizeCache<String>.bucketedWidth(for: 15.9) == 0)
        #expect(HorizontalFittingSizeCache<String>.bucketedWidth(for: 16) == 16)
        #expect(HorizontalFittingSizeCache<String>.bucketedWidth(for: 100.5) == 96)
        #expect(HorizontalFittingSizeCache<String>.bucketedWidth(for: 111.9) == 96)
        #expect(HorizontalFittingSizeCache<String>.bucketedWidth(for: 112) == 112)
    }

    // MARK: - 命中与失效

    @Test func sameFingerprintAndWidthHitsCache() {
        var cache = HorizontalFittingSizeCache<String>()
        #expect(cache.cachedHeight(fingerprint: "code-v1", proposedWidth: 800) == nil)
        cache.store(fingerprint: "code-v1", proposedWidth: 800, height: 640)
        #expect(cache.cachedHeight(fingerprint: "code-v1", proposedWidth: 800) == 640)
    }

    @Test func widthJitterWithinSameBucketStillHits() {
        var cache = HorizontalFittingSizeCache<String>()
        cache.store(fingerprint: "code-v1", proposedWidth: 800, height: 640)
        // 窗口缩放期间的小幅宽度抖动（同一 16pt 桶内）不应触发重新测量
        #expect(cache.cachedHeight(fingerprint: "code-v1", proposedWidth: 803.2) == 640)
        #expect(cache.cachedHeight(fingerprint: "code-v1", proposedWidth: 812.7) == 640)
        // 跨桶 → 失效
        #expect(cache.cachedHeight(fingerprint: "code-v1", proposedWidth: 799.9) == nil)
    }

    @Test func changedFingerprintMisses() {
        var cache = HorizontalFittingSizeCache<String>()
        cache.store(fingerprint: "code-v1", proposedWidth: 800, height: 640)
        // 流式追加 token 后指纹变化 → 必须重新测量
        #expect(cache.cachedHeight(fingerprint: "code-v1\nnew token", proposedWidth: 800) == nil)
    }

    @Test func crossBucketWidthMisses() {
        var cache = HorizontalFittingSizeCache<String>()
        cache.store(fingerprint: "code-v1", proposedWidth: 800, height: 640)
        #expect(cache.cachedHeight(fingerprint: "code-v1", proposedWidth: 816) == nil)
    }

    @Test func storeOverwritesPreviousMeasurement() {
        var cache = HorizontalFittingSizeCache<String>()
        cache.store(fingerprint: "a", proposedWidth: 100, height: 10)
        cache.store(fingerprint: "b", proposedWidth: 200, height: 20)
        // 只保留最近一次测量，旧指纹不再命中
        #expect(cache.cachedHeight(fingerprint: "a", proposedWidth: 100) == nil)
        #expect(cache.cachedHeight(fingerprint: "b", proposedWidth: 200) == 20)
    }

    // MARK: - P1 回归场景

    /// 模拟流式间歇 / 父视图重求值：内容指纹不变时，
    /// 连续 120 帧的 update + 测量询问只应发生一次真实测量。
    /// 旧实现（每次 updateNSView 无条件清缓存）此处为 120 次。
    @Test func repeatedUpdatesWithUnchangedContentMeasureOnce() {
        var cache = HorizontalFittingSizeCache<String>()
        let content = String(repeating: "x", count: 50_000)
        var measurementCount = 0

        for _ in 0..<120 {
            if cache.cachedHeight(fingerprint: content, proposedWidth: 800) == nil {
                measurementCount += 1  // 此处对应昂贵的 NSHostingView.fittingSize
                cache.store(fingerprint: content, proposedWidth: 800, height: 640)
            }
        }

        #expect(measurementCount == 1)
    }

    /// 反向契约：内容确实变化（流式逐 token 追加）时，
    /// 每帧都必须重新测量，否则会返回过期高度。
    @Test func streamingGrowthInvalidatesEveryToken() {
        var cache = HorizontalFittingSizeCache<String>()
        var content = ""
        var measurementCount = 0

        for step in 0..<100 {
            content += "token\(step) "
            if cache.cachedHeight(fingerprint: content, proposedWidth: 800) == nil {
                measurementCount += 1
                cache.store(fingerprint: content, proposedWidth: 800, height: CGFloat(100 + step))
            }
        }

        #expect(measurementCount == 100)
        #expect(cache.cachedHeight(fingerprint: content, proposedWidth: 800) == 199)
    }

    // MARK: - 共享存储(跨物化复用)

    /// 模拟 List 惰性行:视图滚出被拆除、滚回重建 —— 新 Coordinator
    /// 的本地单槽为空,但共享存储应命中,无需重新测量。
    @Test func sharedStoreSurvivesCoordinatorRebuild() {
        HorizontalFittingSizeStore.shared.removeAll()
        defer { HorizontalFittingSizeStore.shared.removeAll() }

        // 第一个"Coordinator"测量并写入共享存储
        var firstCoordinator = HorizontalFittingSizeCache<String>()
        firstCoordinator.store(fingerprint: "code-v1", proposedWidth: 800, height: 640)
        HorizontalFittingSizeStore.shared.store(fingerprint: "code-v1", proposedWidth: 800, height: 640)

        // 行重建:新单槽为空,共享命中
        let rebuilt = HorizontalFittingSizeCache<String>()
        #expect(rebuilt.cachedHeight(fingerprint: "code-v1", proposedWidth: 800) == nil)
        #expect(
            HorizontalFittingSizeStore.shared.height(fingerprint: "code-v1", proposedWidth: 807.5) == 640
        )  // 同一 16pt 桶内
        #expect(
            HorizontalFittingSizeStore.shared.height(fingerprint: "code-v2", proposedWidth: 800) == nil
        )  // 指纹变化 → 失效
    }

    @Test func sharedStoreEvictsBounded() {
        HorizontalFittingSizeStore.shared.removeAll()
        defer { HorizontalFittingSizeStore.shared.removeAll() }

        for i in 0..<600 {
            HorizontalFittingSizeStore.shared.store(
                fingerprint: "code-\(i)",
                proposedWidth: 800,
                height: CGFloat(i)
            )
        }
        // LRU 有界:最早的条目被驱逐
        #expect(HorizontalFittingSizeStore.shared.height(fingerprint: "code-0", proposedWidth: 800) == nil)
        #expect(HorizontalFittingSizeStore.shared.height(fingerprint: "code-599", proposedWidth: 800) == 599)
    }
}
