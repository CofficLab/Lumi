import Foundation

/// RAG 工具类集合
enum RAGUtils {
    /// 格式化时间间隔，使其更加人类可读
    /// - Parameter milliseconds: 时间间隔（毫秒）
    /// - Returns: 格式化后的字符串，小于1000ms显示毫秒，大于等于1000ms显示秒
    static func formatDuration(_ milliseconds: TimeInterval) -> String {
        if milliseconds >= 1000 {
            let seconds = milliseconds / 1000
            return String(format: "%.2fs", seconds)
        } else {
            return String(format: "%.2fms", milliseconds)
        }
    }
}
