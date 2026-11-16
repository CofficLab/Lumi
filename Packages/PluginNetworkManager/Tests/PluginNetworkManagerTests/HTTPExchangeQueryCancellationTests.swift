import Foundation
import Testing
@testable import PluginNetworkManager

/// HTTP 日志查询的协作式取消（#1247）。
///
/// ## 为什么要有这组测试
///
/// 设置页每收到一次交换存储通知就递增修订号并发起一轮重载；一轮重载包含
/// 一次列表分页查询外加计数 / 每日图表 / 最近域名三个统计查询。曾经的实现
/// 用 `Task.detached` 发起这些查询且不保留句柄，修订突发时旧查询不会被取消，
/// 继续把整段扫描跑完，与新查询争抢 CPU / 内存 / 数据库 / 磁盘。
///
/// 修复有两层：
/// 1. 视图层只保留一个重载任务，防抖合并突发，取消传播到每个子查询，并在
///    发起统计前与每次 await 后校验代次；
/// 2. store 层的批量扫描在循环里检查 `Task.isCancelled`，被取代时尽快停下，
///    而不是跑完整段扫描。
///
/// 这组用例锁定第 2 层（store 协作式取消）与「父任务取消 → detached 查询停止」
/// 的传播形态（视图层 `runCancellableQuery` 的同构复刻）。视图层的防抖 / 单任务
/// 保留 / 代次校验属于 SwiftUI 装配，由构建与下面的机制用例共同保障。
@MainActor
@Suite("HTTP 日志查询被取代时协作式取消", .serialized)
struct HTTPExchangeQueryCancellationTests {

    private func makeStore() -> HTTPExchangeStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTTPQueryCancel-\(UUID().uuidString)", isDirectory: true)
        return HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
    }

    /// 播种 count 条已完成记录（offset 越大越新），域名由 domainFor 决定。
    private func seed(
        _ store: HTTPExchangeStore,
        count: Int,
        base: Date,
        domainFor: (Int) -> String = { _ in "example.com" }
    ) {
        for offset in 0..<count {
            let domain = domainFor(offset)
            let response = HTTPURLResponse(
                url: URL(string: "https://\(domain)/")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let request = URLRequest(url: URL(string: "https://\(domain)/api/\(offset)")!)
            let record = store.begin(
                request: request,
                startedAt: base.addingTimeInterval(TimeInterval(offset))
            )!
            store.finish(record, response: response, body: Data())
        }
    }

    // MARK: - 计数查询

    @Test("被取消的计数查询提前停止，未取消时仍返回完整计数")
    func cancelledCountQueriesStopEarly() async {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let base = Date().addingTimeInterval(-7200)
        // 1100 条 → loadListCount 需扫 3 批（500/500/100）。
        seed(store, count: 1100, base: base)

        // 未取消：完整计数。
        let fullSnapshot = await Task { store.loadSnapshotCount() }.value
        let fullList = await Task { store.loadListCount() }.value
        #expect(fullSnapshot == 1100)
        #expect(fullList == 1100)

        // 取消后再求值：循环首批即检查到取消，提前停下。
        let snapshotTask = Task { store.loadSnapshotCount() }
        snapshotTask.cancel()
        let cancelledSnapshot = await snapshotTask.value
        #expect(cancelledSnapshot == 0, "被取消的总数查询不得跑完扫描")

        let listTask = Task { store.loadListCount() }
        listTask.cancel()
        let cancelledList = await listTask.value
        #expect(cancelledList < 1100, "被取消的过滤计数不得跑完整段扫描，实际 \(cancelledList)")
    }

    // MARK: - 列表分页查询

    @Test("被取消的列表分页查询提前停止，未取消时仍返回首页")
    func cancelledListPageStopsEarly() async {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let base = Date().addingTimeInterval(-7200)
        seed(store, count: 300, base: base)

        let fullPage = await Task { store.loadListPage(limit: 40) }.value
        #expect(fullPage.records.count == 40)

        let pageTask = Task { store.loadListPage(limit: 40) }
        pageTask.cancel()
        let cancelledPage = await pageTask.value
        #expect(cancelledPage.records.isEmpty, "被取消的分页查询不得返回扫描结果")
    }

    // MARK: - 最近域名查询

    @Test("被取消的最近域名查询提前停止，未取消时仍返回域名集合")
    func cancelledRecentDomainsStopsEarly() async {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let base = Date().addingTimeInterval(-7200)
        seed(store, count: 300, base: base, domainFor: { "host\($0).example.com" })

        let fullDomains = await Task { store.loadRecentDomains() }.value
        #expect(fullDomains.count == 300)

        let domainsTask = Task { store.loadRecentDomains() }
        domainsTask.cancel()
        let cancelledDomains = await domainsTask.value
        #expect(cancelledDomains.isEmpty, "被取消的域名查询不得跑完抓取与解析")
    }

    // MARK: - 每日图表查询（取消不得污染持久缓存）

    @Test("被取消的每日图表查询返回空且不污染缓存，随后正常查询仍正确")
    func cancelledDailySeriesReturnsEmptyAndKeepsCacheIntact() async {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        // 记录落在最近几天，确保图表需要刷新当日计数。
        let base = Date().addingTimeInterval(-3 * 24 * 3600)
        seed(store, count: 120, base: base)

        // 先取消一次：应在刷新查询前返回空，且不把半截计数写入持久缓存。
        let cancelledTask = Task { store.loadDailyCountSeries() }
        cancelledTask.cancel()
        let cancelledSeries = await cancelledTask.value
        #expect(cancelledSeries.points.isEmpty, "被取消的图表查询应返回空序列")

        // 随后正常查询：若缓存被半截计数污染，这里会读到错误值。
        let fullSeries = await Task { store.loadDailyCountSeries() }.value
        let total = fullSeries.points.reduce(0) { $0 + $1.count }
        #expect(total == 120, "取消不得污染每日计数缓存，正常查询应读到全部 120 条，实际 \(total)")
    }

    // MARK: - 取消传播形态（视图层 runCancellableQuery 的同构复刻）

    /// 复刻视图层 `runCancellableQuery`：detached 查询不继承取消，靠
    /// `withTaskCancellationHandler` 把父任务取消转发给它。
    private func cancellableQuery<T: Sendable>(
        _ operation: @escaping @Sendable () -> T
    ) async -> T {
        let task = Task.detached(priority: .utility, operation: operation)
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    @Test("父任务取消会传播到 detached 查询并使其提前停止")
    func parentCancellationReachesDetachedQuery() async {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let base = Date().addingTimeInterval(-7200)
        seed(store, count: 1100, base: base)

        // 未取消的父任务：detached 查询跑完，返回完整计数。
        let fullCount = await cancellableQuery { store.loadListCount() }
        #expect(fullCount == 1100)

        // 取消父任务：onCancel 把取消转发给 detached 查询，扫描提前停下。
        let parent = Task { await cancellableQuery { store.loadListCount() } }
        parent.cancel()
        let cancelledCount = await parent.value
        #expect(cancelledCount < 1100, "父任务取消必须传播到 detached 查询，实际 \(cancelledCount)")
    }
}