import Testing
import Darwin
import Foundation
@testable import KitHttp

/// 复现 issue #119：长时间运行 / 多步工具调用后 fd 耗尽，
/// 导致工具系统与网络系统同时失败（EMFILE / Too many open files）。
///
/// 本套件覆盖「网络侧」的根因：`KitHttp.HTTPClient` 每次新建都创建一个新的
/// `URLSession`，若不在释放时 `invalidateAndCancel()`，其连接 socket 会随调用次数
/// 持续累积，最终耗尽进程 fd。
///
/// ## 测量方式
///
/// 直接数「进程 fd 总数」会被同进程内的 loopback 服务器干扰（它 accept 的连接
/// 也是进程 fd）。因此改用 `SocketProbe` 只统计**远端端口等于服务器监听端口**的
/// socket —— 即客户端侧连接，从而精确排除服务端 fd 的影响。
///
/// ## 判定
///
/// `URLSession` 的连接会滞留在连接池中（这正是泄漏的机制），因此请求结束后
/// 客户端 socket 数应当收敛到较小值（连接池按主机复用）。若每次新建 client 都
/// 遗留一批连接，计数会随请求次数线性增长。
@Suite("FD Leak Reproduction", .serialized)
struct FDLeakReproductionTests {

    /// 测量 `iterations` 次请求后仍存活的客户端连接数。
    private func measureLiveClientSockets(
        iterations: Int,
        makeClient: () -> HTTPClient
    ) async throws -> (live: Int, succeeded: Int, port: UInt16) {
        guard let server = LoopbackHTTPServer() else { return (-1, 0, 0) }
        server.start()
        defer { server.stop() }

        let url = URL(string: "http://127.0.0.1:\(server.port)/data")!
        var succeeded = 0

        for _ in 0..<iterations {
            let client = makeClient()
            if (try? await client.sendRequestWithResponse(request: URLRequest(url: url))) != nil {
                succeeded += 1
            }
        }

        // 给 ARC 与 URLSession 内部队列留出释放时间
        try await Task.sleep(nanoseconds: 3_000_000_000)
        let live = SocketProbe.clientSocketCount(peerPort: server.port)
        return (live, succeeded, server.port)
    }

    /// 主用例：反复用**新建**的 client 请求同一地址。
    ///
    /// 修复前每请求遗留约 1 个连接 socket，40 次请求后存活连接数会显著高于连接池
    /// 应有的数量；修复后（`deinit` 中 `invalidateAndCancel()`）应收敛到个位数。
    @Test("反复新建 HTTPClient 不应遗留大量连接")
    func repeatedClientCreationDoesNotLeakConnections() async throws {
        let iterations = 40
        let result = try await measureLiveClientSockets(iterations: iterations) {
            HTTPClient()
        }

        #expect(result.succeeded == iterations, "预期全部请求成功，实际 \(result.succeeded)/\(iterations)")
        #expect(result.live >= 0, "socket 统计失败")

        // 连接池按主机复用连接，正常情况只需 1~2 个；
        // 若接近请求次数，说明每次新建的 client 都在遗留连接（issue #119）。
        #expect(
            result.live <= 5,
            """
            检测到连接泄漏：\(iterations) 次请求后仍有 \(result.live) 个到服务器的存活连接。
            正常连接池只需 1~2 个。这与 issue #119 一致：反复新建 `HTTPClient` 时
            未释放 URLSession，连接 socket 持续累积，长时间运行后耗尽 fd，
            导致工具与网络系统同时报 EMFILE。
            """
        )
    }

    /// 对照组：复用同一个 client，用于证明测量本身可靠（同样应只有 1~2 个连接）。
    @Test("复用同一 HTTPClient 只保留少量连接（对照组）")
    func reusedClientKeepsConnectionCountLow() async throws {
        let iterations = 40
        let shared = HTTPClient()
        let result = try await measureLiveClientSockets(iterations: iterations) {
            shared
        }

        #expect(result.succeeded == iterations, "预期全部请求成功，实际 \(result.succeeded)/\(iterations)")
        #expect(
            result.live <= 5,
            "复用同一 client 时连接数异常：\(result.live)"
        )
    }
}
