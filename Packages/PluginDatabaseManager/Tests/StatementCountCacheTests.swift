@testable import DatabaseManagerPlugin
import Foundation
import Testing

/// 「工具栏每次 body 求值都重新 split 整段 SQL」的回归测试（#1254）。
///
/// `MainView.toolbar` 此前在视图构造时同步调用 `SQLStatementParser.split(queryText).count`，
/// 普通编辑与无关的 ViewModel 发布都会在主线程重复整段词法解析。修复：语句计数经
/// `StatementCountCache` 按文本 memo，只在 `queryText` 真正变化时重算；工具栏读取
/// ViewModel 上 O(1) 的存储值 `statementCount`。
@Suite("StatementCountCache")
struct StatementCountCacheTests {
    @Test func countMatchesParserSplit() {
        var cache = StatementCountCache()
        let sql = "SELECT 1; SELECT 2; SELECT 3;"
        #expect(cache.count(for: sql) == SQLStatementParser.split(sql).count)
        #expect(cache.count(for: sql) == 3)
    }

    @Test func repeatedSameTextDoesNotReparse() {
        var cache = StatementCountCache()
        let sql = "SELECT 1; SELECT 2;"
        _ = cache.count(for: sql)
        _ = cache.count(for: sql)
        _ = cache.count(for: sql)
        #expect(cache.parseCount == 1, "文本不变时不应重复解析")
    }

    @Test func changedTextReparses() {
        var cache = StatementCountCache()
        _ = cache.count(for: "SELECT 1;")
        #expect(cache.parseCount == 1)
        let count = cache.count(for: "SELECT 1; SELECT 2;")
        #expect(count == 2)
        #expect(cache.parseCount == 2)
    }

    @Test func commentOnlyScriptCountsZero() {
        var cache = StatementCountCache()
        #expect(cache.count(for: "-- just a comment\n/* block */") == 0)
    }

    @Test func emptyScriptCountsZero() {
        var cache = StatementCountCache()
        #expect(cache.count(for: "") == 0)
    }
}

/// ViewModel 集成：语句计数随 `queryText` 更新，无关刷新不改变它（#1254）。
@MainActor
@Suite(.serialized)
struct DatabaseViewModelStatementCountTests {
    @Test func statementCountSeededOnInit() {
        let viewModel = DatabaseViewModel(loadSavedConfigs: false)
        #expect(viewModel.statementCount == SQLStatementParser.split(viewModel.queryText).count)
    }

    @Test func statementCountTracksQueryTextChanges() {
        let viewModel = DatabaseViewModel(loadSavedConfigs: false)
        viewModel.queryText = "SELECT 1; SELECT 2; SELECT 3;"
        #expect(viewModel.statementCount == 3)
        viewModel.queryText = "SELECT 1;"
        #expect(viewModel.statementCount == 1)
    }

    @Test func unrelatedPublicationDoesNotChangeStatementCount() {
        let viewModel = DatabaseViewModel(loadSavedConfigs: false)
        viewModel.queryText = "SELECT 1; SELECT 2;"
        #expect(viewModel.statementCount == 2)
        // 模拟无关的 ViewModel 发布（加载态 / 结果 / 错误），计数必须保持不变。
        viewModel.isLoading = true
        viewModel.queryResult = QueryResult(columns: ["x"], rows: [], rowsAffected: 0)
        viewModel.errorMessage = "boom"
        #expect(viewModel.statementCount == 2)
    }

    @Test func resettingSameQueryTextKeepsCount() {
        let viewModel = DatabaseViewModel(loadSavedConfigs: false)
        viewModel.queryText = "SELECT 1; SELECT 2;"
        viewModel.queryText = "SELECT 1; SELECT 2;"
        #expect(viewModel.statementCount == 2)
    }
}