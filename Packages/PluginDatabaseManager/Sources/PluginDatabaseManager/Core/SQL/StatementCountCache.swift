import Foundation

/// 工具栏「Run All (N)」语句计数的 memo 缓存（#1254）。
///
/// `SQLStatementParser.split` 会词法扫描整段脚本，并对每条已提交语句再扫一遍
/// 以剔除纯注释内容，开销随脚本长度增长。此前 `MainView.toolbar` 在每次 SwiftUI
/// body 求值时都重新 `split`，普通编辑与无关的 ViewModel 发布（isLoading、queryResult…）
/// 都会在主线程触发整段重解析。
///
/// 这里按文本内容 memo：文本不变直接返回上次结果，只有真正变化才重解析。
/// `parseCount` 记录实际调用解析器的次数，供回归测试断言「无关刷新不重解析」。
struct StatementCountCache {
    private(set) var parseCount = 0
    private var cachedText: String?
    private var cachedCount = 0

    mutating func count(for text: String) -> Int {
        if let cachedText, cachedText == text {
            return cachedCount
        }
        parseCount += 1
        let count = SQLStatementParser.split(text).count
        cachedText = text
        cachedCount = count
        return count
    }
}