import Foundation

extension String {
    /// 构建上下文窗口的 tooltip 文本
    static func contextTooltip(used: Int?, max: Int) -> String {
        if let used, used > 0 {
            return "Context: \(used.formattedContextSizeDetail) / \(max.formattedContextSizeDetail)"
        }
        return "Context window: \(max.formattedContextSizeDetail)"
    }
}
