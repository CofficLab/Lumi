import Foundation

/// 把网络层任意粒度的字节 chunk 累积成完整的 SSE 帧(以空行分隔)。
///
/// 背景:`NetworkProvider.stream` 按 ~16KB 回调原始字节,不保证 SSE 帧完整;
/// 若直接对每个 chunk 调用 `XiaomiEventParser.parse`(无状态纯函数),
/// 跨 chunk 的帧——例如较大的 `content_block_delta`(thinking / text)——
/// 会被切成两半后各自解析失败、事件整体丢失。
///
/// 丢失的 content 会让 Lumi 存储的 assistant 消息与模型实际输出不一致,
/// 下一轮请求回传历史消息时,缓存前缀单元失配 → 命中率下降。
///
/// 本累积器维护跨 chunk 的 pending buffer,按空行(`\n\n` / `\r\n\r\n`)切出完整帧,
/// 残缺帧留到下一个 chunk 补齐;流结束时的残余也按一帧处理。
final class XiaomiSSESequenceAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = Data()

    /// 追加一块数据,切出所有完整帧返回;不完整的残帧留在内部缓冲。
    func appendAndDrain(_ data: Data) -> [Data] {
        lock.lock()
        defer { lock.unlock() }
        pending.append(data)
        var frames: [Data] = []
        let lf = Data("\n\n".utf8)
        let crlf = Data("\r\n\r\n".utf8)
        while true {
            let lfRange = pending.range(of: lf)
            let crlfRange = pending.range(of: crlf)
            let range: Range<Data.Index>?
            switch (lfRange, crlfRange) {
            case let (l?, c?):
                range = l.lowerBound < c.lowerBound ? l : c
            case let (l?, nil):
                range = l
            case let (nil, c?):
                range = c
            case (nil, nil):
                range = nil
            }
            guard let range else { break }
            let frame = pending.subdata(in: 0..<range.lowerBound)
            pending.removeSubrange(0..<range.upperBound)
            if !frame.isEmpty {
                frames.append(frame)
            }
        }
        return frames
    }

    /// 流结束:取出残余字节(无空行结尾的最后一个帧),并清空缓冲。
    func drainRemaining() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard !pending.isEmpty else { return nil }
        let frame = pending
        pending.removeAll(keepingCapacity: true)
        return frame
    }
}
