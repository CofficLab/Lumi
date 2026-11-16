import Foundation

/// 决定按下 Return 时应打开哪一条搜索结果。
///
/// 面板用 `selectedIndex` 跟踪箭头键高亮的条目，提交必须沿用该高亮项，
/// 而不是无条件打开第一条（回归 #839）。抽出为纯函数以便对边界做单元测试：
/// 高亮项越界或无结果时返回 `nil`，调用方据此不打开任何文件。
enum FileSearchSubmitSelection {
    static func indexToOpen(selectedIndex: Int, resultCount: Int) -> Int? {
        guard selectedIndex >= 0, selectedIndex < resultCount else { return nil }
        return selectedIndex
    }
}