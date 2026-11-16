import Testing
import Foundation
@testable import QuickFileSearchPlugin

/// 回归 #839：Cmd+P 面板按 Return 必须打开箭头键高亮的条目，而不是无条件
/// 打开第一条。`FileSearchSubmitSelection.indexToOpen` 是从视图 `selectedIndex`
/// 提交逻辑中抽出的纯函数，这里锁定其选择与越界边界行为。
struct FileSearchSubmitSelectionTests {

    @Test func submitOpensHighlightedNotFirst() {
        #expect(FileSearchSubmitSelection.indexToOpen(selectedIndex: 1, resultCount: 2) == 1)
    }

    @Test func submitOpensFirstWhenFirstHighlighted() {
        #expect(FileSearchSubmitSelection.indexToOpen(selectedIndex: 0, resultCount: 2) == 0)
    }

    @Test func submitOpensLastHighlighted() {
        #expect(FileSearchSubmitSelection.indexToOpen(selectedIndex: 2, resultCount: 3) == 2)
    }

    @Test func submitWithNoResultsOpensNothing() {
        #expect(FileSearchSubmitSelection.indexToOpen(selectedIndex: 0, resultCount: 0) == nil)
    }

    @Test func submitWithOutOfRangeIndexOpensNothing() {
        #expect(FileSearchSubmitSelection.indexToOpen(selectedIndex: 5, resultCount: 2) == nil)
        #expect(FileSearchSubmitSelection.indexToOpen(selectedIndex: -1, resultCount: 2) == nil)
    }
}