import CSQLite
import Foundation
import Testing

@testable import ProjectRAGEngine

/// Task 2.1a：探测当前链接的 CSQLite 是否内置 FTS5，决定索引词法检索走
/// FTS5（Task 2.1b）还是 Swift BM25（Task 2.1b'）。探测结果登记在 TestPlan 备注。
@Suite struct RAGFTS5AvailabilityProbeTests {
    @Test("bundled SQLite FTS5 availability probe")
    func probeFTS5Availability() throws {
        var db: OpaquePointer?
        #expect(sqlite3_open(":memory:", &db) == SQLITE_OK)
        defer { sqlite3_close(db) }

        var options: [String] = []
        var pragma: OpaquePointer?
        #expect(sqlite3_prepare_v2(db, "PRAGMA compile_options;", -1, &pragma, nil) == SQLITE_OK)
        defer { sqlite3_finalize(pragma) }
        while sqlite3_step(pragma) == SQLITE_ROW {
            if let text = sqlite3_column_text(pragma, 0) {
                options.append(String(cString: text))
            }
        }

        let createStatus = sqlite3_exec(db, "CREATE VIRTUAL TABLE probe USING fts5(x);", nil, nil, nil)
        let fts5Available = createStatus == SQLITE_OK

        print("[FTS5 probe] available=\(fts5Available) compile_options=\(options.joined(separator: ","))")

        // 探测结论必须与 compile_options 一致；无 FTS5 时走 Task 2.1b' Swift BM25。
        #expect(fts5Available == options.contains("ENABLE_FTS5"))

        if fts5Available {
            var insert: OpaquePointer?
            #expect(
                sqlite3_prepare_v2(db, "INSERT INTO probe(x) VALUES ('hello world');", -1, &insert, nil)
                    == SQLITE_OK
            )
            defer { sqlite3_finalize(insert) }
            #expect(sqlite3_step(insert) == SQLITE_DONE)

            var match: OpaquePointer?
            #expect(
                sqlite3_prepare_v2(db, "SELECT rowid FROM probe WHERE probe MATCH 'hello';", -1, &match, nil)
                    == SQLITE_OK
            )
            defer { sqlite3_finalize(match) }
            #expect(sqlite3_step(match) == SQLITE_ROW)
        } else {
            // 无 FTS5 → Task 2.1b' Swift BM25 路线。此分支即探测结论。
            #expect(!options.contains("ENABLE_FTS5"))
        }
    }
}