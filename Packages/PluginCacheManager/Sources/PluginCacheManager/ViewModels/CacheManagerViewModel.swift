import Foundation
import ProviderDiskCache

/// 缓存管理视图模型。
///
/// 所有 await 后的共享状态写回都带代次校验（仓库约定）：
/// 旧请求晚到时直接丢弃，不覆盖新上下文。加载标记用计数管理，
/// 重叠操作的收尾不会误关新任务的转圈。
@MainActor
final class CacheManagerViewModel: ObservableObject {
    @Published private(set) var report: DiskCacheUsageReport = .empty
    @Published private(set) var isLoading = false
    @Published private(set) var isClearing = false
    @Published private(set) var feedback: String?

    private let cache: any DiskCacheProviding
    private var reportGeneration = 0
    private var clearGeneration = 0
    private var loadingCount = 0

    init(cache: any DiskCacheProviding) {
        self.cache = cache
    }

    var totalDescription: String {
        formattedBytes(report.totalBytes)
    }

    func description(for usage: DiskCacheBucketUsage) -> String {
        String(
            format: pluginLocalization.string("%@ · %lld entries"),
            formattedBytes(usage.byteCount),
            usage.entryCount
        )
    }

    func refresh() {
        reportGeneration += 1
        let generation = reportGeneration
        beginLoading()
        Task { [weak self] in
            guard let self else { return }
            defer { self.endLoading() }
            let report = await self.cache.usageReport()
            guard self.reportGeneration == generation else { return }
            self.report = report
        }
    }

    func clearAll() {
        clearGeneration += 1
        reportGeneration += 1
        let clearGen = clearGeneration
        let reportGen = reportGeneration
        isClearing = true
        feedback = nil
        Task { [weak self] in
            guard let self else { return }
            await self.cache.clearAll()
            let report = await self.cache.usageReport()
            guard self.clearGeneration == clearGen else { return }
            self.isClearing = false
            self.feedback = pluginLocalization.string("Cache cleared.")
            guard self.reportGeneration == reportGen else { return }
            self.report = report
        }
    }

    func clearBucket(pluginID: String) {
        reportGeneration += 1
        let generation = reportGeneration
        beginLoading()
        Task { [weak self] in
            guard let self else { return }
            defer { self.endLoading() }
            await self.cache.clearBucket(pluginID: pluginID)
            let report = await self.cache.usageReport()
            guard self.reportGeneration == generation else { return }
            self.report = report
        }
    }

    private func beginLoading() {
        loadingCount += 1
        isLoading = true
    }

    private func endLoading() {
        loadingCount = max(0, loadingCount - 1)
        isLoading = loadingCount > 0
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}