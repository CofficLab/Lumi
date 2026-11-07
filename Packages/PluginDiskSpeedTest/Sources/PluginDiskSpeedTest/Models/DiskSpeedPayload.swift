import Foundation

/// 磁盘测速卡片的结构化载荷。
///
/// ## 为什么载荷存在 `Message.content` 里
///
/// `MessageManaging.updateMessage(id:in:content:)` **只能改 content**，
/// 改不了 `metadata`（见 `DefaultMessageManager.updateMessage` 与
/// 持久化实现 `MessageStore.updateMessage`，两者都只写 `content` 字段）。
///
/// 测速卡片却必须能从一个状态推进到另一个状态：
/// 「正在测试…」→「完成：读 1.2 GB/s，写 900 MB/s」。
///
/// 如果把载荷放在 `metadata`，卡片一旦插入就永远停在「正在测试」——
/// 因为没有任何接口能改写已经落库的 metadata。
///
/// 因此本插件把载荷放进 `content`，`metadata` 只保留时间线标记。
/// 这样状态推进只需要一次 `updateMessage` 调用即可完成，
/// 也避免了「content 与 metadata 各存一份数据」导致两边不一致的问题。
///
/// 代价是 `content` 不再是人话。但消息正文的语义本来就是「给人看的摘要」，
/// 而渲染器会优先解析结构化载荷、失败时再回退到纯文本展示，
/// 因此这个代价是可控的。
public struct DiskSpeedPayload: Codable, Sendable, Equatable {

    /// 测速状态。
    public enum Phase: String, Codable, Sendable, Equatable {
        /// 测速进行中。
        case running
        /// 测速已完成。
        case finished
        /// 测速失败。
        case failed
    }

    /// 当前状态。
    public let phase: Phase

    /// 顺序读取速度（字节/秒）。`nil` 表示尚未测出或该项失败。
    public let readBytesPerSecond: Double?

    /// 顺序写入速度（字节/秒）。`nil` 表示尚未测出或该项失败。
    public let writeBytesPerSecond: Double?

    /// 顺序读取测试的字节数。
    public let readBytes: Int64

    /// 顺序写入测试的字节数。
    public let writeBytes: Int64

    /// 测速使用的目录路径。
    public let directory: String

    /// 失败原因。仅在 `phase == .failed` 时有意义。
    public let failureReason: String?

    public init(
        phase: Phase,
        readBytesPerSecond: Double? = nil,
        writeBytesPerSecond: Double? = nil,
        readBytes: Int64 = 0,
        writeBytes: Int64 = 0,
        directory: String = "",
        failureReason: String? = nil
    ) {
        self.phase = phase
        self.readBytesPerSecond = readBytesPerSecond
        self.writeBytesPerSecond = writeBytesPerSecond
        self.readBytes = readBytes
        self.writeBytes = writeBytes
        self.directory = directory
        self.failureReason = failureReason
    }

    /// 测速进行中的载荷。
    public static func running(directory: String) -> DiskSpeedPayload {
        DiskSpeedPayload(phase: .running, directory: directory)
    }

    /// 测速失败的载荷。
    public static func failed(directory: String, reason: String) -> DiskSpeedPayload {
        DiskSpeedPayload(phase: .failed, directory: directory, failureReason: reason)
    }

    /// 测速完成的载荷。
    public static func finished(
        readBytesPerSecond: Double?,
        writeBytesPerSecond: Double?,
        readBytes: Int64 = 0,
        writeBytes: Int64 = 0,
        directory: String = ""
    ) -> DiskSpeedPayload {
        DiskSpeedPayload(
            phase: .finished,
            readBytesPerSecond: readBytesPerSecond,
            writeBytesPerSecond: writeBytesPerSecond,
            readBytes: readBytes,
            writeBytes: writeBytes,
            directory: directory
        )
    }

    /// 是否已完成（无论成功还是失败）。
    public var isTerminal: Bool { phase != .running }

    /// 读取速度的可读文本。
    public var displayReadSpeed: String? {
        Self.formattedSpeed(readBytesPerSecond)
    }

    /// 写入速度的可读文本。
    public var displayWriteSpeed: String? {
        Self.formattedSpeed(writeBytesPerSecond)
    }

    /// 把字节/秒格式化成人类可读的速度文本。
    ///
    /// - Parameter bytesPerSecond: 字节/秒。`nil` 或非正值返回 nil。
    /// - Returns: 形如 `1.20 GB/s` 的文本。
    static func formattedSpeed(_ bytesPerSecond: Double?) -> String? {
        guard let bytesPerSecond, bytesPerSecond > 0 else { return nil }
        let gigabyte = 1_000_000_000.0
        let megabyte = 1_000_000.0
        let kilobyte = 1_000.0

        if bytesPerSecond >= gigabyte {
            return String(format: "%.2f GB/s", bytesPerSecond / gigabyte)
        }
        if bytesPerSecond >= megabyte {
            return String(format: "%.1f MB/s", bytesPerSecond / megabyte)
        }
        if bytesPerSecond >= kilobyte {
            return String(format: "%.1f KB/s", bytesPerSecond / kilobyte)
        }
        return String(format: "%.0f B/s", bytesPerSecond)
    }

    /// 把字节数格式化成可读的体积文本。
    static func formattedBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }
        let gigabyte = 1_000_000_000.0
        let megabyte = 1_000_000.0
        let kilobyte = 1_000.0
        let value = Double(bytes)
        if value >= gigabyte {
            return String(format: "%.2f GB", value / gigabyte)
        }
        if value >= megabyte {
            return String(format: "%.1f MB", value / megabyte)
        }
        if value >= kilobyte {
            return String(format: "%.1f KB", value / kilobyte)
        }
        return "\(bytes) B"
    }
}
