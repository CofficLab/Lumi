import Foundation

/// `Retry-After` 响应头解析。
///
/// RFC 9110 §10.2.3 规定 `Retry-After` 有两种形式：
///
/// - `delay-seconds`：非负整数秒数，如 `Retry-After: 30`；
/// - `HTTP-date`：绝对时间点，如 `Retry-After: Wed, 21 Oct 2015 07:28:00 GMT`。
///
/// ## 为什么必须解析它
///
/// 供应商在过载（429 / 529）时常用该头明确告知「多久之后再试」。Lumi 此前
/// 完全忽略该头：服务端要求等待 30s，客户端仍按本地 1s/2s 的确定性退避
/// 抢着重试。对于 529 这类**全局**过载信号，这意味着客户端在服务端明确
/// 要求静默的窗口内继续加压，反而延长了恢复时间。
///
/// ## 语义约定
///
/// - 头缺失、格式非法、或 `HTTP-date` 指向过去 → 返回 `nil`（无有效建议），
///   由本地指数退避决定等待时长。
/// - `delay-seconds: 0` → 返回 `0`，语义是「现在就可以重试」；调用方按
///   「建议值必须大于 0 才生效」处理，因此它等价于无建议。
/// - 建议值超过 ``maxHonoredSeconds`` 时按上限截断：服务端可能给出非常长
///   的等待时间（如 3600s），在交互式会话里无上限地阻塞一个回合会让用户
///   以为应用卡死。
public enum HTTPRetryAfter {
    /// 响应头名称。
    public static let headerName = "Retry-After"

    /// 单次重试最多等待的秒数上限。
    public static let maxHonoredSeconds: TimeInterval = 60

    /// 从响应头字典解析建议等待时间（秒）。
    ///
    /// - Parameters:
    ///   - headers: 响应头字典，键的大小写不敏感。
    ///   - now: 换算 `HTTP-date` 的基准时间，默认当前时间。
    /// - Returns: 建议等待秒数；无有效建议时返回 `nil`。
    public static func seconds(from headers: [String: String], now: Date = Date()) -> TimeInterval? {
        guard let raw = value(in: headers) else { return nil }
        return seconds(fromHeaderValue: raw, now: now)
    }

    /// 解析单个 `Retry-After` 头的值。
    ///
    /// - Parameters:
    ///   - raw: 响应头原始值。
    ///   - now: 换算 `HTTP-date` 的基准时间，默认当前时间。
    /// - Returns: 建议等待秒数；无有效建议时返回 `nil`。
    public static func seconds(fromHeaderValue raw: String, now: Date = Date()) -> TimeInterval? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 形式一：delay-seconds（非负整数秒数）。
        //
        // 用 `Double` 而非 `Int` 解析：极大的值（如 10^20）会超出 `Int` 范围
        // 而解析失败，那样会被误判为「格式非法」而整个忽略——正确做法是
        // 识别出它确实是一个秒数，再按上限截断。
        if trimmed.allSatisfy({ $0.isASCII && $0.isNumber }),
           let seconds = Double(trimmed),
           seconds >= 0 {
            return capped(seconds)
        }

        // 形式二：HTTP-date（IMF-fixdate / RFC 850 / asctime）。
        guard let date = httpDate(from: trimmed) else { return nil }
        let interval = date.timeIntervalSince(now)
        // 指向过去的时间点等价于「现在就可以重试」，但没有任何等待价值：
        // 与 `delay-seconds: 0` 一样按「无建议」处理。
        guard interval > 0 else { return nil }
        return capped(interval)
    }

    /// 大小写不敏感地读取响应头。
    static func value(in headers: [String: String]) -> String? {
        if let exact = headers[headerName] {
            return exact
        }
        let target = headerName.lowercased()
        for (key, value) in headers where key.lowercased() == target {
            return value
        }
        return nil
    }

    private static func capped(_ seconds: TimeInterval) -> TimeInterval {
        min(max(seconds, 0), maxHonoredSeconds)
    }

    private static func httpDate(from string: String) -> Date? {
        for format in httpDateFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    /// HTTP-date 的三种合法书写形式（RFC 9110 §5.6.7）。
    private static let httpDateFormats = [
        "EEE, dd MMM yyyy HH:mm:ss zzz", // IMF-fixdate
        "EEEE, dd-MMM-yy HH:mm:ss zzz", // RFC 850
        "EEE MMM d HH:mm:ss yyyy", // asctime
    ]
}
