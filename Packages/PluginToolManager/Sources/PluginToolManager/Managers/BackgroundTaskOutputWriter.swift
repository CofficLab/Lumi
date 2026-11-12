import Foundation

/// 后台任务输出的落盘写入器。
///
/// 线程安全：ShellTool 的流式回调来自进程管道的后台线程，而完成通知在
/// actor 上产生，两边会并发写同一个文件，因此所有状态都受锁保护。
///
/// 磁盘上限：超过 `maxBytes` 时**保留尾部**并写入截断提示。构建/测试日志的
/// 诊断价值集中在末尾（错误、失败摘要），丢掉头部反而让模型拿不到关键信息。
final class BackgroundTaskOutputWriter: @unchecked Sendable {
    /// 截断提示，写在保留下来的尾部之后。
    static let truncationNotice = "\n[output truncated: only the tail is kept]\n"

    let fileURL: URL
    private let maxBytes: Int
    private let lock = NSLock()
    private var handle: FileHandle?
    private var byteCount = 0
    private var didTruncate = false

    init(fileURL: URL, maxBytes: Int) throws {
        self.fileURL = fileURL
        self.maxBytes = max(0, maxBytes)
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        self.handle = try FileHandle(forWritingTo: fileURL)
    }

    /// 追加一段输出。超限时裁剪为尾部并置位截断标记。
    func append(_ text: String) {
        guard !text.isEmpty else { return }
        let data = Data(text.utf8)

        lock.lock()
        defer { lock.unlock() }

        guard let handle else { return }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            byteCount += data.count
            if byteCount > maxBytes {
                trimToTail(handle)
            }
        } catch {
            // 输出落盘失败不应影响进程生命周期：任务仍需正常结束并通知模型。
        }
    }

    /// 读取文件末尾最多 `limit` 个字节，用于完成通知里的摘录。
    func tail(limit: Int) -> String {
        guard limit > 0 else { return "" }
        lock.lock()
        defer { lock.unlock() }

        guard let reader = try? FileHandle(forReadingFrom: fileURL) else { return "" }
        defer { try? reader.close() }
        guard let size = try? reader.seekToEnd(), size > 0 else { return "" }

        let keep = UInt64(min(Int(size), limit))
        try? reader.seek(toOffset: size - keep)
        guard let data = try? reader.read(upToCount: Int(keep)), !data.isEmpty else {
            return ""
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// 输出是否因超过磁盘上限而被裁剪。
    var isTruncated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didTruncate
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        try? handle?.close()
        handle = nil
    }

    /// 把文件裁剪到上限内，只保留尾部并追加截断提示。
    ///
    /// 必须整体重写：单纯停止写入会丢掉日志末尾——而末尾恰恰是模型最需要的
    /// 失败摘要。
    private func trimToTail(_ handle: FileHandle) {
        let notice = Data(Self.truncationNotice.utf8)
        let keep = UInt64(max(0, maxBytes - notice.count))
        guard keep > 0 else { return }

        guard let reader = try? FileHandle(forReadingFrom: fileURL) else { return }
        let size = (try? reader.seekToEnd()) ?? 0
        guard size > keep else {
            try? reader.close()
            return
        }
        try? reader.seek(toOffset: size - keep)
        let tail = (try? reader.read(upToCount: Int(keep))) ?? Data()
        try? reader.close()

        guard !tail.isEmpty else { return }
        do {
            try handle.truncate(atOffset: 0)
            try handle.seek(toOffset: 0)
            try handle.write(contentsOf: tail)
            try handle.write(contentsOf: notice)
            byteCount = tail.count + notice.count
            didTruncate = true
        } catch {
            // 裁剪失败时保留已写入的内容，不再尝试。
        }
    }
}
