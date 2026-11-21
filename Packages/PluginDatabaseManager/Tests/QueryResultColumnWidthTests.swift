import Foundation
import Testing
@testable import DatabaseManagerPlugin

/// 查询结果表格列宽估算（#1253 回归）。
///
/// 列宽只依赖 `QueryResult` 本身：按列名 + 前 50 行采样估算并钳制在
/// 上下限内。历史实现把它做成视图计算属性，SwiftUI 不缓存计算属性，
/// 表格宽度、每个表头与每个单元格各自触发一次全量扫描，一次渲染
/// 接近 Θ(50 × (V + 1) × C²) 次采样访问；现在 body 计算一次后下传复用。
@MainActor
struct QueryResultColumnWidthTests {

    private func makeResult(
        columns: [String],
        rows: [[DatabaseValue]]
    ) -> QueryResult {
        QueryResult(columns: columns, rows: rows, rowsAffected: 0)
    }

    @Test("列宽只采样前 50 行，超出部分不影响宽度")
    func samplesOnlyFirst50Rows() {
        let short = String(repeating: "a", count: 30)
        let long = String(repeating: "b", count: 60)
        let rows = (0..<60).map { index in
            [DatabaseValue.string(index < 50 ? short : long)]
        }
        let widths = QueryResultView.columnWidths(for: makeResult(columns: ["note"], rows: rows))

        // 采样到第 50 行为止：30 字符 × 8pt + 24pt = 264，未触及 320 上限。
        #expect(widths == [264])
    }

    @Test("列宽钳制在上下限内，列名长度是下限基准")
    func clampsToBounds() {
        let result = makeResult(
            columns: ["id", "memo"],
            rows: [
                [DatabaseValue.integer(1), DatabaseValue.string(String(repeating: "x", count: 1000))],
            ]
        )
        let widths = QueryResultView.columnWidths(for: result)

        #expect(widths[0] == 80, "短内容与短列名应取下限 80")
        #expect(widths[1] == 320, "超长内容应取上限 320")
    }

    @Test("NULL 与 BLOB 的文本化不参与膨胀，估算结果稳定")
    func handlesNullAndBlobValuesStably() {
        let result = makeResult(
            columns: ["blob_col"],
            rows: [
                [DatabaseValue.data(Data(repeating: 0, count: 10_000))],
                [DatabaseValue.null],
            ]
        )
        let first = QueryResultView.columnWidths(for: result)
        let second = QueryResultView.columnWidths(for: result)

        // BLOB 文本化为 "<BLOB 10000 bytes>"（18 字符），两次估算必须一致。
        #expect(first == second)
        #expect(first[0] == CGFloat(18 * 8 + 24))
    }
}
