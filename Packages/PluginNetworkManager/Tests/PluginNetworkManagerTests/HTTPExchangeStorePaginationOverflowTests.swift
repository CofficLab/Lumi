import Foundation
import Testing
@testable import PluginNetworkManager

/// HTTP 日志分页：一次扫描产出的匹配数可能超过 `limit`，溢出匹配不得被永久丢弃（#215）。
///
/// `loadListPage` 按 `fetchWindow = max(limit*4, limit)` 批量扫描（newest-first，
/// 游标 `startedAt < cursor`）。曾经的实现：
/// - `matches.append(...)` 后 `matches.count` 可能 > limit；
/// - 返回 `Array(matches.prefix(limit))` 截断溢出匹配；
/// - 但 `nextCursor` 取自 `rawRecords.last?.startedAt`（整个扫描窗口的末端），
///   已经越过那些被截断的匹配；扫描不足一窗时还直接 `hasMore = false`。
///
/// 于是溢出匹配既不在本页返回，也永远不会在下一页出现。正确行为：游标只前进到
/// **本页实际返回的最后一条匹配**，让下一页重新取回溢出匹配。
///
/// 这组用例用「逐页 drain 直到 hasMore=false」来锁定不变量：所有匹配都必须被取回，
/// 且不重复。时间戳互不相同，不依赖任何哈希碰撞或等长时间戳。
@MainActor
@Suite("HTTP 日志分页溢出匹配不丢失")
struct HTTPExchangeStorePaginationOverflowTests {

    private func makeStore() -> HTTPExchangeStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTTPPaginationOverflow-\(UUID().uuidString)", isDirectory: true)
        return HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
    }

    /// 按给定时间偏移播种记录（offset 越大越新），返回记录 id。
    private func seed(
        _ store: HTTPExchangeStore,
        offsets: [Int],
        domain: String,
        base: Date
    ) -> [UUID] {
        let response = HTTPURLResponse(
            url: URL(string: "https://\(domain)/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        var ids: [UUID] = []
        for offset in offsets {
            let request = URLRequest(url: URL(string: "https://\(domain)/api/\(offset)")!)
            let record = store.begin(
                request: request,
                startedAt: base.addingTimeInterval(TimeInterval(offset))
            )!
            store.finish(record, response: response, body: Data())
            ids.append(record.id)
        }
        return ids
    }

    /// 从最新一页开始逐页 drain，直到 hasMore=false（或游标无法前进）。
    private func drain(
        _ store: HTTPExchangeStore,
        limit: Int,
        status: HTTPExchangeStatusFilter = .all,
        domain: String? = nil
    ) -> [HTTPExchangeListSnapshot] {
        var collected: [HTTPExchangeListSnapshot] = []
        var cursor: Date?
        var rounds = 0
        while rounds < 200 {
            let page = store.loadListPage(
                limit: limit,
                beforeStartedAt: cursor,
                status: status,
                domain: domain
            )
            collected.append(contentsOf: page.records)
            rounds += 1
            guard page.hasMore, let next = page.nextCursor, !page.records.isEmpty else { break }
            cursor = next
        }
        return collected
    }

    // MARK: - 扫描不足一窗即结束（issue 主复现：51 条匹配 < 4×window）

    @Test("扫描不足一窗时溢出匹配仍须可翻页取回")
    func overflowMatchesSurviveWhenScanEndsBelowWindow() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        // limit=3 → fetchWindow=12；仅 4 条匹配（< 一窗），首页即溢出 1 条。
        let ids = seed(store, offsets: [0, 1, 2, 3], domain: "example.com", base: base)

        let firstPage = store.loadListPage(limit: 3)
        #expect(firstPage.records.count == 3)
        #expect(firstPage.hasMore, "首页就有溢出匹配时 hasMore 必须为 true，否则第 4 条永远翻不到")

        let all = drain(store, limit: 3)
        #expect(
            Set(all.map(\.id)) == Set(ids),
            "翻页必须取回全部 \(ids.count) 条匹配，实际 \(all.count) 条"
        )
        #expect(all.count == ids.count, "溢出匹配不得被重复返回")
    }

    // MARK: - 扫描正好填满窗口（游标越过溢出匹配）

    @Test("满窗扫描溢出时游标不得越过未返回的匹配")
    func overflowMatchesSurviveWhenScanFillsWindow() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        // limit=2 → fetchWindow=8；9 条匹配，首窗扫满 8 条且全部匹配 → 溢出 6 条。
        let ids = seed(store, offsets: Array(0..<9), domain: "example.com", base: base)

        let all = drain(store, limit: 2)
        #expect(
            Set(all.map(\.id)) == Set(ids),
            "满窗扫描溢出时翻页必须取回全部 \(ids.count) 条，实际 \(all.count) 条"
        )
        #expect(all.count == ids.count, "溢出匹配不得被重复返回")
    }

    // MARK: - 带域名过滤的溢出（匹配是扫描行的子集）

    @Test("带域名过滤的溢出翻页须取回全部匹配且不混入他域")
    func overflowMatchesSurviveWithDomainFilter() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        // limit=3 → fetchWindow=12；共 12 行，其中 5 行匹配目标域名（分散排列）。
        let matchIDs = seed(store, offsets: [11, 9, 7, 5, 3], domain: "match.example.com", base: base)
        _ = seed(store, offsets: [10, 8, 6, 4, 2, 1, 0], domain: "other.example.com", base: base)

        let all = drain(store, limit: 3, domain: "match.example.com")
        #expect(
            Set(all.map(\.id)) == Set(matchIDs),
            "带域名过滤的溢出翻页必须取回全部 \(matchIDs.count) 条匹配，实际 \(all.count) 条"
        )
        #expect(all.allSatisfy { $0.url.contains("match.example.com") }, "不得返回非匹配域名的记录")
    }
}
