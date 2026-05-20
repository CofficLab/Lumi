import Foundation

public enum RAGUtils {
    /// 格式化时间间隔，使其更加人类可读
    public static func formatDuration(_ milliseconds: TimeInterval) -> String {
        if milliseconds >= 1000 {
            let seconds = milliseconds / 1000
            return String(format: "%.2fs", seconds)
        } else {
            return String(format: "%.2fms", milliseconds)
        }
    }
}
