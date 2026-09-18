import Foundation

/// ACP 传输抽象。
///
/// 本地模式通过 stdio；远程模式（三期）通过 HTTP / WebSocket。
/// 传输层只搬运字节帧，不做协议语义处理；收到完整帧后回调 `onMessage`。
public protocol ACPTransport: AnyObject {
    /// 收到一帧完整消息（UTF-8 数据）。
    var onMessage: ((Data) -> Void)? { get set }
    /// 输入流到达 EOF（例如 stdin 关闭）。宿主可借此退出进程。
    var onEOF: (() -> Void)? { get set }
    /// 启动传输（开始接收）。
    func start() throws
    /// 发送一帧消息。
    func send(_ data: Data) throws
    /// 停止传输。
    func stop()
}

public extension ACPTransport {
    /// 默认空实现：不感知 EOF 的传输无需改动。
    var onEOF: (() -> Void)? {
        get { nil }
        set {}
    }
}

/// stdio 传输实现：从 stdin 逐帧读取、向 stdout 写入。
///
/// 帧格式：newline-delimited JSON（每行一条消息，与 MCP stdio 约定一致）。
/// 注意：协议外输出（日志、诊断）必须走 stderr，禁止污染 stdout 协议流。
public final class StdioTransport: ACPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var running = false

    public var onMessage: ((Data) -> Void)?
    public var onEOF: (() -> Void)?

    public init() {}

    public func start() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !running else { return }
        running = true

        FileHandle.standardInput.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            if data.isEmpty {
                // EOF：停止读取，通知宿主（可退出进程），保持 stdout 可用以便收尾。
                FileHandle.standardInput.readabilityHandler = nil
                self.stop()
                self.onEOF?()
                return
            }
            self.processIncoming(data)
        }
    }

    public func send(_ data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        var frame = data
        frame.append(0x0A) // newline 帧分隔
        // 注意：对管道/终端执行 synchronize() 会返回 EINVAL，此处不调用。
        try FileHandle.standardOutput.write(contentsOf: frame)
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard running else { return }
        running = false
        FileHandle.standardInput.readabilityHandler = nil
    }

    /// 是否正在运行。
    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    // MARK: - 帧解析

    private func processIncoming(_ data: Data) {
        lock.lock()
        buffer.append(data)
        var frames: [Data] = []
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            var frame = buffer[..<newlineIndex]
            // 兼容 CRLF
            if frame.last == 0x0D {
                frame = frame.dropLast()
            }
            frames.append(Data(frame))
            buffer.removeSubrange(...newlineIndex)
        }
        lock.unlock()

        for frame in frames {
            guard !frame.isEmpty else { continue }
            onMessage?(frame)
        }
    }
}
