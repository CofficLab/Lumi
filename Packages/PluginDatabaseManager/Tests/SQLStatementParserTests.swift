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

    // MARK: - PostgreSQL 美元引用（回归 #279）

    @Test("美元引用函数体必须作为单条语句，不得按分号拆分（回归 #279）")
    func dollarQuotedFunctionBodyIsSingleStatement() {
        let sql = """
        CREATE FUNCTION f() RETURNS void AS $$
        BEGIN
          PERFORM 1;
          PERFORM 2;
        END;
        $$ LANGUAGE plpgsql;
        """
        let statements = SQLStatementParser.split(sql)
        #expect(statements.count == 1)
        #expect(statements.first == String(sql.dropLast()))
    }

    @Test("带标签与嵌套的美元引用同样保持单条语句（回归 #279）")
    func taggedAndNestedDollarQuotesAreSingleStatement() {
        let tagged = "CREATE FUNCTION g() RETURNS void AS $body$ BEGIN PERFORM 1; PERFORM 2; END; $body$ LANGUAGE plpgsql"
        #expect(SQLStatementParser.split(tagged) == [tagged])
        let nested = "SELECT $outer$ a; $inner$ b; c $inner$ d; $outer$ AS s"
        #expect(SQLStatementParser.split(nested) == [nested])
    }

    @Test("美元引用之外的分号仍正常切分语句（回归 #279）")
    func statementsOutsideDollarQuotesStillSplit() {
        let sql = "SELECT 1; SELECT $$a;b$$; SELECT 2"
        #expect(SQLStatementParser.split(sql) == ["SELECT 1", "SELECT $$a;b$$", "SELECT 2"])
    }

    @Test("位置参数 $1/$2 不被当成美元引用起始符（回归 #279）")
    func positionalParametersAreNotDollarQuotes() {
        #expect(SQLStatementParser.split("SELECT $1; SELECT $2") == ["SELECT $1", "SELECT $2"])
        #expect(SQLStatementParser.split("SELECT $1") == ["SELECT $1"])
    }

    @Test("美元引用体在骨架中被剥离，写关键字不参与只读判定（回归 #279）")
    func dollarQuotedBodyStrippedFromSkeleton() {
        let skeleton = SQLStatementParser.stripLiteralsAndComments("SELECT $$DROP TABLE t; DELETE$$ AS s")
        #expect(!skeleton.contains("DROP"))
        #expect(!skeleton.contains("DELETE"))
        #expect(skeleton.contains("SELECT"))
        #expect(skeleton.contains("AS s"))
    }

    @Test("美元引用体内的引号与分号不提前结束引用（回归 #279）")
    func dollarQuoteIgnoresInnerQuotesAndSemicolons() {
        let sql = "SELECT $tag$a'x'b; c$tag$ AS s; SELECT 2"
        #expect(SQLStatementParser.split(sql) == ["SELECT $tag$a'x'b; c$tag$ AS s", "SELECT 2"])
    }
}
