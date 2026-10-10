import Darwin
import Foundation

/// 极简 loopback HTTP 服务器，用于 fd 泄漏测试。
///
/// 关键行为：
/// - 按 HTTP/1.1 规范读取请求（正确解析 `Content-Length`，支持带 body 的 POST）；
/// - 同一连接上支持多次请求（keep-alive），响应后**不关闭**连接，
///   从而让客户端把连接留在自己的连接池里；
/// - 监听 `127.0.0.1` 的临时端口，不依赖外网。
///
/// 这样，客户端若不复用 / 不释放 URLSession，其连接 fd 会持续累积。
final class LoopbackHTTPServer: @unchecked Sendable {

    // MARK: - Properties

    let port: UInt16

    private let listenFD: Int32
    private let acceptQueue = DispatchQueue(label: "loopback.server.accept")
    private let stateLock = NSLock()
    private var acceptedFDs: [Int32] = []
    private var isRunning = false

    /// 响应体大小，便于测试不同载荷。
    var responseBodyBytes: Int = 2

    // MARK: - Initialization

    init?() {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }

        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bound = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { close(fd); return nil }

        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        guard named == 0 else { close(fd); return nil }

        self.port = UInt16(bigEndian: addr.sin_port)
        self.listenFD = fd

        guard listen(fd, 128) == 0 else { close(fd); return nil }
    }

    deinit { stop() }

    // MARK: - Public

    func start() {
        stateLock.lock()
        guard !isRunning else { stateLock.unlock(); return }
        isRunning = true
        stateLock.unlock()
        acceptQueue.async { [weak self] in self?.acceptLoop() }
    }

    func stop() {
        stateLock.lock()
        let fds = acceptedFDs
        acceptedFDs.removeAll()
        let wasRunning = isRunning
        isRunning = false
        stateLock.unlock()

        guard wasRunning else { return }
        for fd in fds { close(fd) }
        close(listenFD)
    }

    /// 服务端当前持有的连接数（即客户端保持的连接）。
    var connectionCount: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return acceptedFDs.count
    }

    // MARK: - Private

    private func acceptLoop() {
        while true {
            stateLock.lock()
            let running = isRunning
            stateLock.unlock()
            guard running else { return }

            var clientAddr = sockaddr()
            var clientLen = socklen_t(MemoryLayout<sockaddr>.size)
            let clientFD = accept(listenFD, &clientAddr, &clientLen)
            guard clientFD >= 0 else { return }

            stateLock.lock()
            if isRunning {
                acceptedFDs.append(clientFD)
            } else {
                close(clientFD)
            }
            stateLock.unlock()

            let bodyBytes = responseBodyBytes
            DispatchQueue.global().async {
                Self.serve(fd: clientFD, bodyBytes: bodyBytes)
            }
        }
    }

    /// 在一个连接上按 keep-alive 循环处理请求，读满请求体后再响应。
    private static func serve(fd: Int32, bodyBytes: Int) {
        var pending = Data()

        while true {
            // 1. 读满请求头
            guard let headerRange = readHeaders(fd: fd, buffer: &pending) else { return }
            let headerData = pending.subdata(in: 0..<headerRange)
            let headerText = String(decoding: headerData, as: UTF8.self)

            // 2. 解析 Content-Length，读满请求体
            let contentLength = parseContentLength(headerText)
            let bodyStart = headerRange
            while pending.count - bodyStart < contentLength {
                guard readMore(fd: fd, buffer: &pending) else { return }
            }
            // 丢弃该请求（头 + 体）
            pending.removeSubrange(0..<(bodyStart + contentLength))

            // 3. 响应
            let body = Data(repeating: UInt8(ascii: "x"), count: bodyBytes)
            let head = "HTTP/1.1 200 OK\r\n"
                + "Content-Type: application/octet-stream\r\n"
                + "Content-Length: \(body.count)\r\n"
                + "\r\n"
            var payload = Data(head.utf8)
            payload.append(body)
            let sent = payload.withUnsafeBytes { raw -> Int in
                guard let base = raw.baseAddress else { return -1 }
                return send(fd, base, raw.count, 0)
            }
            guard sent > 0 else { return }
            // 故意不关闭连接：让客户端把连接留在连接池中
        }
    }

    /// 读直到出现 `\r\n\r\n`，返回请求头结束位置（不含分隔符后的偏移）。
    private static func readHeaders(fd: Int32, buffer: inout Data) -> Int? {
        let terminator = Data("\r\n\r\n".utf8)
        while true {
            if let range = buffer.range(of: terminator) {
                return range.upperBound
            }
            guard readMore(fd: fd, buffer: &buffer) else { return nil }
        }
    }

    /// 从 socket 再读一块数据，失败或对端关闭时返回 false。
    private static func readMore(fd: Int32, buffer: inout Data) -> Bool {
        var chunk = [UInt8](repeating: 0, count: 16 * 1024)
        let read = recv(fd, &chunk, chunk.count, 0)
        guard read > 0 else { return false }
        buffer.append(contentsOf: chunk[0..<read])
        return true
    }

    /// 从请求头文本中解析 `Content-Length`；缺失时视为 0。
    private static func parseContentLength(_ header: String) -> Int {
        for line in header.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            guard parts[0].lowercased() == "content-length" else { continue }
            return Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
        }
        return 0
    }
}
