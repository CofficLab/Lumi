import Foundation

/// 启动环境的磁盘空间判定结果。
public enum BootstrapSpaceVerdict: Equatable, Sendable {
    /// 可用空间满足启动要求。
    case sufficient
    /// 可用空间不足，应用无法可靠启动。
    case insufficient(availableBytes: Int64, requiredBytes: Int64)
    /// 探测失败，无法判断。此时**不得**据此阻断启动。
    case unknown
}

/// 启动前的环境预检。
///
/// - Important: SwiftData 会把底层 SQLite 失败（`database or disk is full`、
///   `SQLITE_FULL`、只读卷等）一律折叠成 `SwiftDataError code 1` + 空 userInfo，
///   真正的 errno 只出现在 CoreData 写到统一日志的那一行里。也就是说应用自己的
///   错误链**拿不到**「磁盘满」这个根因——插件抛上来的只有
///   "未能完成操作。(SwiftData.SwiftDataError 错误。)"。
///
///   所以宿主不能等错误传上来再归因，必须在装配内核**之前**主动探测卷容量：
///   只有主动探测才能把「磁盘满」变成可呈现、可操作的启动失败。
public enum BootstrapEnvironment {

    /// 启动所需的最少可用磁盘空间：2 GiB。
    ///
    /// Lumi 的本地数据量级不小（消息库数百 MB、RAG 索引数百 MB、HTTP 记录库
    /// 持续增长），可用空间低于 2 GiB 时 SQLite 写入随时可能因 ENOSPC 失败，
    /// 最终表现为「某个插件启动失败」这种用户完全看不懂的报错。
    public static let defaultRequiredFreeBytes: Int64 = 2 * 1024 * 1024 * 1024

    /// 判定给定可用空间是否够启动。
    ///
    /// - Parameters:
    ///   - availableBytes: 探测到的可用字节数；`nil` 表示探测失败。
    ///   - requiredBytes: 启动所需的最小字节数。
    /// - Returns: 判定结果。探测失败时返回 `.unknown`，绝不据此阻断启动。
    public static func evaluate(
        availableBytes: Int64?,
        requiredBytes: Int64 = defaultRequiredFreeBytes
    ) -> BootstrapSpaceVerdict {
        guard let availableBytes else { return .unknown }
        guard requiredBytes > 0 else { return .sufficient }
        return availableBytes < requiredBytes
            ? .insufficient(availableBytes: availableBytes, requiredBytes: requiredBytes)
            : .sufficient
    }

    /// 探测某个目录所在卷的可用字节数。
    ///
    /// - Returns: 可用字节数；探测失败返回 `nil`。
    public static func availableBytes(at directory: URL) -> Int64? {
        do {
            let values = try directory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            guard let capacity = values.volumeAvailableCapacity else { return nil }
            return Int64(capacity)
        } catch {
            return nil
        }
    }

    /// 一次性完成「探测 + 判定」。
    public static func evaluateSpace(
        at directory: URL,
        requiredBytes: Int64 = defaultRequiredFreeBytes
    ) -> BootstrapSpaceVerdict {
        evaluate(
            availableBytes: availableBytes(at: directory),
            requiredBytes: requiredBytes
        )
    }
}

/// 字节数的确定性格式化。
///
/// 不使用 `ByteCountFormatter`：它的输出随 locale 变化且带窄不换行空格，
/// 无法写进稳定的断言。这里固定用 GB / MB，保证同一数值在任何机器上
/// 都得到同一个字符串。
public enum BootstrapByteFormat {

    private static let gib: Double = 1024 * 1024 * 1024
    private static let mib: Double = 1024 * 1024

    /// 把字节数格式化成 `1.5 GB` / `512 MB` 这样的字符串。
    public static func string(_ bytes: Int64) -> String {
        let value = max(0, Double(bytes))
        if value >= gib {
            return decimal(value / gib) + " GB"
        }
        return decimal(value / mib) + " MB"
    }

    /// 保留一位小数，但去掉多余的 `.0`。
    private static func decimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded - rounded.rounded()) < 0.0001 {
            return String(Int(rounded.rounded()))
        }
        return String(format: "%.1f", rounded)
    }
}
