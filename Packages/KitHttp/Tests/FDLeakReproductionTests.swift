import Testing
import Darwin
import Foundation
@testable import KitHttp

/// 复现 issue #119：长时间运行 / 多步工具调用后 fd 耗尽，
/// 导致工具系统与网络系统同时失败（EMFILE / Too many open files）。
///
/// 本套件覆盖「网络侧」的根因：`KitHttp.HTTPClient` 每次新建都创建一个新的
/// `URLSession`，且从不 `invalidateAndCancel()`，导致其连接 fd 随调用次数持续累积。
///
/// 复现方式：用进程内 loopback 服务器（见 `LoopbackHTTPServer`）承接真实 TCP 连接，
/// 服务端保持 keep-alive 不主动断开，从而使客户端连接滞留在连接池里。
/// 若客户端不复用 / 不释放 session，fd 就会线性增长。
///
/// > 断言阈值取「每请求平均泄漏 > 0.5 个 fd」，远低于实测值（约 2 fd/请求），
/// > 既能在真实泄漏时稳定失败，也留出足够余量避免偶发抖动导致误报。
@Suite("FD Leak Reproduction", .serialized)
struct FDLeakReproductionTests {

    /// 复现主用例：反复用**新建**的 client 请求同一地址。
    ///
    /// 当前实现下 fd 会持续累积且长期不释放 → 断言失败，即复现了 issue #119。
    /// 修复（例如让 `HTTPClient` 在 `deinit` 中 `invalidateAndCancel()`，
    /// 或复用长生命周期 client）后，本用例应转为通过。
    @Test("反复新建 HTTPClient 请求会持续累积 fd")
    func repeatedClientCreationLeaksFileDescriptors() async throws {
        guard let server = LoopbackHTTPServer() else {
            Issue.record("无法启动 loopback 服务器")
            return
        }
        server.start()
        defer { server.stop() }

        let url = URL(string: "http://127.0.0.1:\(server.port)/data")!

        // 预热：让 URLSession 的全局基础设施完成初始化，避免把一次性开销算进增量
        for _ in 0..<3 {
            let warmup = HTTPClient()
            _ = try? await warmup.sendRequestWithResponse(request: URLRequest(url: url))
        }
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let before = FileDescriptorProbe.openCount()
        var succeeded = 0
        let iterations = 40

        for _ in 0..<iterations {
            let client = HTTPClient()
            if (try? await client.sendRequestWithResponse(request: URLRequest(url: url))) != nil {
                succeeded += 1
            }
        }

        // 给 ARC 与 URLSession 内部队列留出回收时间，避免把「尚未回收」误判为「泄漏」
        try await Task.sleep(nanoseconds: 3_000_000_000)
        let after = FileDescriptorProbe.openCount()
        let leaked = after - before
        let perRequest = Double(leaked) / Double(iterations)

        // 先确认确实是「泄漏」而非「请求根本没成功」
        #expect(succeeded == iterations, "预期全部请求成功，实际 \(succeeded)/\(iterations)")
        #expect(before > 0 && after > 0, "fd 计数失败")

        // 核心断言：fd 不应随「新建 client」线性累积
        #expect(
            perRequest <= 0.5,
            """
            检测到 fd 泄漏：\(iterations) 次请求使 fd 从 \(before) 增至 \(after) \
            （Δ\(leaked)，约 \(String(format: "%.2f", perRequest)) 个/请求），等待 3 秒后仍未释放。
            这与 issue #119 描述一致：反复新建 `HTTPClient` 会累积连接 fd，
            长时间运行后耗尽 fd → 工具与网络系统同时报 EMFILE。
            服务端当前仍持有 \(server.connectionCount) 个连接。
            """
        )
    }

    /// 对照组：复用同一个 client 时 fd 应收敛（连接被池化复用，而非每次新建）。
    ///
    /// 该用例用于证明上面的失败确实来自「反复新建」，而不是 loopback 服务器或
    /// 测试环境自身在累积 fd。
    @Test("复用同一 HTTPClient 不会累积 fd（对照组）")
    func reusedClientDoesNotLeakFileDescriptors() async throws {
        guard let server = LoopbackHTTPServer() else {
            Issue.record("无法启动 loopback 服务器")
            return
        }
        server.start()
        defer { server.stop() }

        let url = URL(string: "http://127.0.0.1:\(server.port)/data")!
        let client = HTTPClient()

        for _ in 0..<3 {
            _ = try? await client.sendRequestWithResponse(request: URLRequest(url: url))
        }
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let before = FileDescriptorProbe.openCount()
        var succeeded = 0
        let iterations = 40

        for _ in 0..<iterations {
            if (try? await client.sendRequestWithResponse(request: URLRequest(url: url))) != nil {
                succeeded += 1
            }
        }

        try await Task.sleep(nanoseconds: 1_000_000_000)
        let after = FileDescriptorProbe.openCount()

        #expect(succeeded == iterations, "预期全部请求成功，实际 \(succeeded)/\(iterations)")
        #expect(
            after - before <= 2,
            "复用同一 client 时 fd 不应增长，实际 Δ\(after - before)"
        )
    }
}
