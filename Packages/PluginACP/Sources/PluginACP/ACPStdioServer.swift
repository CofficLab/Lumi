import Foundation
import ProviderACP

/// ACP stdio 服务器：驱动传输层并派发协议消息。
///
/// - 从 transport 收到完整帧 → `ACPProtocolHandler` 分发。
/// - 分发结果（响应/通知）经 transport 写回。
/// - 所有协议处理在 MainActor 上执行（Lumi 内核为 @MainActor）。
///
/// 约定：协议外的诊断输出必须走 stderr，不得污染 stdout 协议流。
@MainActor
public final class ACPStdioServer {
    private let transport: any ACPTransport
    private let handler: ACPProtocolHandler

    /// 输入 EOF 回调（透传 transport.onEOF），宿主可据此退出进程。
    public var onEOF: (() -> Void)?

    public init(transport: any ACPTransport, handler: ACPProtocolHandler) {
        self.transport = transport
        self.handler = handler
    }

    /// 启动服务器（开始读取 stdin）。
    ///
    /// transport 回调在后台队列触发，这里通过 `Task { @MainActor }`
    /// 重新进入主 actor 后再处理协议消息。
    public func start() throws {
        handler.onSend = { [weak self] message in
            self?.send(message)
        }
        transport.onMessage = { [weak self] data in
            Task { @MainActor [weak self] in
                self?.process(data)
            }
        }
        transport.onEOF = { [weak self] in
            // 排到 MainActor 队列尾部：确保此前收到的帧先被处理完，再通知宿主退出。
            Task { @MainActor [weak self] in
                self?.onEOF?()
            }
        }
        try transport.start()
    }

    /// 停止服务器。
    public func stop() {
        transport.onMessage = nil
        transport.onEOF = nil
        transport.stop()
    }

    /// 向 Client 发送一条消息（供异步事件流 / 回合响应使用）。
    public func sendToClient(_ message: ACPMessage) {
        send(message)
    }

    // MARK: - 消息处理

    private func process(_ data: Data) {
        let message: ACPMessage
        do {
            message = try ACPMessage.decode(data)
        } catch {
            send(.error(id: .null, error: .parseError))
            return
        }

        guard let response = handler.handle(message) else { return }
        send(response)
    }

    private func send(_ message: ACPMessage) {
        do {
            try transport.send(message.encodedData())
        } catch {
            // 写 stdout 失败：协议流不可用，仅记录到 stderr。
            fputs("ACP stdio write failed: \(error)\n", stderr)
        }
    }
}
