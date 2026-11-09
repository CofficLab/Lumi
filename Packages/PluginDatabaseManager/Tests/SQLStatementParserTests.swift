import Foundation
import Testing
@testable import DatabaseManagerPlugin

/// SQL 切分器在「下一个字符正好是字符串末尾」时的越界回归。
///
/// `String.index(_:offsetBy:limitedBy:)` 走到末尾会返回 `endIndex`，
/// 旧实现只判断 `next != nil` 就下标访问，输入以 `-`、`/`、`*` 或未闭合
/// 块注释结尾时会直接 trap。
struct SQLStatementParserTests {
    @Test("以 - / * 结尾的语句不会越界且保留内容", arguments: ["SELECT 1-", "SELECT 1/", "SELECT 1*"])
    func trailingOperatorDoesNotCrash(sql: String) {
        #expect(SQLStatementParser.split(sql) == [sql])
        #expect(SQLStatementParser.stripLiteralsAndComments(sql) == sql)
    }

    @Test("末尾的单独 - / * 会被当成普通内容")
    func loneTrailingCharacters() {
        #expect(SQLStatementParser.split("-") == ["-"])
        #expect(SQLStatementParser.split("/") == ["/"])
        #expect(SQLStatementParser.split("*") == ["*"])
    }

    @Test("未闭合块注释不会越界且不产生可执行语句")
    func unterminatedBlockComment() {
        #expect(SQLStatementParser.split("SELECT 1;/* unterminated") == ["SELECT 1"])
        #expect(SQLStatementParser.split("/*").isEmpty)
        #expect(SQLStatementParser.stripLiteralsAndComments("SELECT 1/*").isEmpty == false)
    }

    @Test("行注释收尾与分号切分保持原有行为")
    func lineCommentAtEnd() {
        #expect(SQLStatementParser.split("SELECT 1;-- trailing") == ["SELECT 1"])
        #expect(SQLStatementParser.stripLiteralsAndComments("SELECT 1 -- tail") == "SELECT 1 ")
    }

    @Test("末尾的单引号不会越界")
    func trailingQuote() {
        #expect(SQLStatementParser.split("SELECT 'abc") == ["SELECT 'abc"])
        #expect(SQLStatementParser.stripLiteralsAndComments("SELECT 'abc") == "SELECT  ")
    }
}
