import Foundation
import Testing
@testable import PluginNetworkManager

/// 回归 #823：在途 Pending 请求（既无 HTTP 状态码也无错误）不得被归入 Abnormal。
///
/// `beginRecord` 在请求发起时就落库，此时 `responseStatusCode` 与 `errorDescription`
/// 均为空，只有 `finish` 才会填入。Abnormal 谓词过去对「无状态码」一律返回 true，
/// 导致尚未返回的 Pending 请求被列表、计数与导出误判为异常。修复后：无状态码时
/// 只有已带错误的终止失败才算异常；非 2xx 状态码仍算异常。
@MainActor
@Suite(.serialized, HTTPExchangeStoreGateTrait())
struct HTTPPendingRequestClassificationTests {

    private func withStore(_ body: (HTTPExchangeStore) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTTPPending-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HTTPExchangeStore(directory: directory, startsRetentionMaintenance: false)
        try body(store)
    }

    /// 只 begin 不 finish：复刻请求仍在途、尚未取得状态码与错误的 Pending 记录。
    private func beginPending(_ store: HTTPExchangeStore, url: String) throws {
        let request = URLRequest(url: try #require(URL(string: url)))
        _ = store.begin(request: request, startedAt: Date().addingTimeInterval(-60))
    }

    private func recordFinished(
        _ store: HTTPExchangeStore,
        url: String,
        status: Int?,
        error: Error?
    ) throws {
        let target = try #require(URL(string: url))
        var request = URLRequest(url: target)
        request.httpMethod = "GET"
        let startedAt = Date().addingTimeInterval(-60)
        let exchange = store.begin(request: request, startedAt: startedAt)
        let response = status.flatMap {
            HTTPURLResponse(url: target, statusCode: $0, httpVersion: "HTTP/1.1", headerFields: nil)
        }
        store.finish(exchange, response: response, error: error, finishedAt: startedAt.addingTimeInterval(0.5))
    }

    @Test("在途 Pending 请求不得计入 Abnormal（**回归 #823**）")
    func pendingRequestIsNotAbnormal() throws {
        try withStore { store in
            try beginPending(store, url: "https://pending.test/inflight")

            #expect(store.loadListCount(status: .abnormal) == 0)
            #expect(store.loadListCount(status: .normal) == 0)
            #expect(store.loadListCount(status: .all) == 1)
            #expect(store.loadListPage(limit: 10, status: .abnormal).records.isEmpty)
        }
    }

    @Test("无状态码但已带错误的传输失败仍归入 Abnormal")
    func transportFailureWithoutStatusIsAbnormal() throws {
        try withStore { store in
            try recordFinished(store, url: "https://transport.test/down", status: nil, error: URLError(.notConnectedToInternet))

            #expect(store.loadListCount(status: .abnormal) == 1)
            #expect(store.loadListCount(status: .normal) == 0)
        }
    }

    @Test("已收到非 2xx 状态码的请求归入 Abnormal")
    func httpErrorStatusIsAbnormal() throws {
        try withStore { store in
            try recordFinished(store, url: "https://api.test/missing", status: 404, error: nil)

            #expect(store.loadListCount(status: .abnormal) == 1)
            #expect(store.loadListCount(status: .normal) == 0)
        }
    }

    @Test("2xx 成功请求归入 Normal 而非 Abnormal")
    func successIsNormalNotAbnormal() throws {
        try withStore { store in
            try recordFinished(store, url: "https://api.test/ok", status: 200, error: nil)

            #expect(store.loadListCount(status: .abnormal) == 0)
            #expect(store.loadListCount(status: .normal) == 1)
        }
    }

    @Test("Pending/传输失败/4xx/2xx 混合时各分类计数与列表正确")
    func mixedRecordsClassifyCorrectly() throws {
        try withStore { store in
            try beginPending(store, url: "https://pending.test/inflight")
            try recordFinished(store, url: "https://transport.test/down", status: nil, error: URLError(.notConnectedToInternet))
            try recordFinished(store, url: "https://api.test/missing", status: 404, error: nil)
            try recordFinished(store, url: "https://api.test/ok", status: 200, error: nil)

            #expect(store.loadListCount(status: .all) == 4)
            #expect(store.loadListCount(status: .abnormal) == 2)
            #expect(store.loadListCount(status: .normal) == 1)

            let abnormalURLs = Set(store.loadListPage(limit: 10, status: .abnormal).records.map(\.url))
            #expect(abnormalURLs == ["https://transport.test/down", "https://api.test/missing"])
        }
    }
}