import Foundation

/// 把网络层任意粒度的字节 chunk 累积成完整的 SSE 帧（以空行分隔）。
final class SSESequenceAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = Data()

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

    func drainRemaining() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard !pending.isEmpty else { return nil }
        let frame = pending
        pending.removeAll(keepingCapacity: true)
        return frame
    }
}
