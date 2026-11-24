import Foundation
import Network
import Testing
@testable import KitDownload

/// 只接受连接、永不返回任何字节的本地服务器，让客户端只能靠超时退出。
private final class SilentHTTPServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "SilentHTTPServer")

    init() throws {
        let parameters = NWParameters(tls: nil, tcp: .init())
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters, on: .any)
        listener.newConnectionHandler = { connection in
            connection.start(queue: self.queue)
        }
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready: ready.signal()
            case .failed: ready.signal()
            default: break
            }
        }
        listener.start(queue: queue)
        ready.wait()
    }

    var port: UInt16 { listener.port?.rawValue ?? 0 }

    func stop() { listener.cancel() }
}

@Suite("DownloadManagerTimeout")
struct DownloadManagerTimeoutTests {
    @Test("配置的 timeoutInterval 作用于内部 HTTP 会话（回归 #485）")
    func configuredTimeoutIntervalAppliesToInternalSession() async throws {
        let server = try SilentHTTPServer()
        defer { server.stop() }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KitDownloadTimeout-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = DownloadManager(
            configuration: .init(downloadDirectory: directory, timeoutInterval: 0.1)
        )

        let started = Date()
        do {
            _ = try await manager.download(
                DownloadTask(
                    url: URL(string: "http://127.0.0.1:\(server.port)/never-responds.bin")!,
                    destination: directory.appendingPathComponent("never-responds.bin"),
                    expectedSize: nil
                )
            )
            Issue.record("无应答服务器不应完成下载")
        } catch {
            // 期待在配置的预算内以超时失败，而不是挂到 URLSession 默认超时。
        }
        let elapsed = Date().timeIntervalSince(started)
        #expect(elapsed < 5)
    }
}
