import Foundation

/// 编辑器正文的轻量文本统计。
///
/// 这些统计需要对整篇正文做一次线性扫描，但必须做到**零分配**：
/// `text.filter { $0 == "\n" }.count` 会构造 `Character` 数组并重新拼接字符串，
/// 在大文件上是可观的额外内存与时间开销（见 issue #1329）。
///
/// - Important: 语义与 `text.filter { $0 == "\n" }.count` **完全一致**，
///   包括 CRLF 的处理：Swift 把 `\r\n` 视作单个 `Character`，因此紧跟在
///   `\r` 之后的 `\n` 不计入换行数。字节扫描时必须复刻这一规则，
///   否则会改变 CRLF 文件的行数统计结果。
public enum EditorTextMetrics: Sendable {

    /// 统计正文中被计入换行的 `\n` 数量。
    ///
    /// 与 `text.filter { $0 == "\n" }.count` 语义一致：
    /// 紧跟在 `\r` 之后的 `\n` 属于 `\r\n` 组合，不单独计数。
    public static func newlineCount(in text: String) -> Int {
        var count = 0
        // 逐字节扫描：native String 的 UTF-8 视图无需拷贝。
        var previousByte: UInt8 = 0
        for byte in text.utf8 {
            if byte == 0x0A, previousByte != 0x0D {
                count += 1
            }
            previousByte = byte
        }
        return count
    }

    /// 正文总行数。
    ///
    /// 语义与 `text.filter { $0 == "\n" }.count + 1` 一致：空正文为 1 行。
    public static func totalLineCount(in text: String) -> Int {
        newlineCount(in: text) + 1
    }
}
