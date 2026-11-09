import Foundation

/// SQL 语句切分器：按 `;` 把一段 SQL 切成独立的可执行语句。
///
/// 尊重：
/// - 单引号字符串字面量（含 `''` 转义）
/// - 双引号标识符（含 `""` 转义）
/// - 反引号标识符（MySQL，含 ` `` ` 转义）
/// - 行注释（`--` 到行尾）
/// - 块注释（`/* ... */`，可嵌套）
///
/// 空语句（仅空白/注释）被过滤。返回的语句保留原始空白以便错误定位。
public enum SQLStatementParser {
    /// 返回 `index` 之后的字符位置；没有下一个字符时返回 `nil`。
    ///
    /// `String.index(_:offsetBy:limitedBy:)` 在恰好走到末尾时会返回
    /// `endIndex`，而调用方随后会直接下标访问，造成越界 trap。这里统一
    /// 把 `endIndex` 归一成 `nil`，让所有 `next` 都保证可安全下标。
    private static func nextIndex(in string: String, after index: String.Index) -> String.Index? {
        guard let next = string.index(index, offsetBy: 1, limitedBy: string.endIndex),
              next < string.endIndex else {
            return nil
        }
        return next
    }

    public static func split(_ sql: String) -> [String] {
        var result: [String] = []
        var current = ""
        var index = sql.startIndex
        var inString: Character? = nil
        var inLineComment = false
        var blockCommentDepth = 0

        /// 去除注释后是否仍有实际内容（避免纯注释语句占位）。
        func hasExecutableContent(_ statement: String) -> Bool {
            var stripped = ""
            var i = statement.startIndex
            var inStr: Character? = nil
            var inLC = false
            var bcDepth = 0
            while i < statement.endIndex {
                let c = statement[i]
                let n = Self.nextIndex(in: statement, after: i)
                if inLC {
                    if c == "\n" { inLC = false }
                    i = statement.index(after: i); continue
                }
                if bcDepth > 0 {
                    if c == "/" && n != nil && statement[n!] == "*" { bcDepth += 1; i = statement.index(after: n!); continue }
                    if c == "*" && n != nil && statement[n!] == "/" { bcDepth -= 1; i = statement.index(after: n!); continue }
                    i = statement.index(after: i); continue
                }
                if let q = inStr {
                    if c == q {
                        if let nn = n, nn < statement.endIndex, statement[nn] == q { i = statement.index(after: nn); continue }
                        inStr = nil
                    }
                    i = statement.index(after: i); continue
                }
                if c == "'" || c == "\"" || c == "`" { inStr = c; i = statement.index(after: i); continue }
                if c == "-" && n != nil && statement[n!] == "-" { inLC = true; i = statement.index(after: i); continue }
                if c == "/" && n != nil && statement[n!] == "*" { bcDepth = 1; i = statement.index(after: n!); continue }
                stripped.append(c)
                i = statement.index(after: i)
            }
            return !stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        func commitCurrentStatement() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && hasExecutableContent(trimmed) {
                result.append(trimmed)
            }
            current = ""
        }

        while index < sql.endIndex {
            let ch = sql[index]
            let next = Self.nextIndex(in: sql, after: index)

            // 行注释状态
            if inLineComment {
                current.append(ch)
                if ch == "\n" { inLineComment = false }
                index = sql.index(after: index)
                continue
            }

            // 块注释状态（可嵌套）
            if blockCommentDepth > 0 {
                current.append(ch)
                if ch == "/" && next != nil && sql[next!] == "*" {
                    blockCommentDepth += 1
                    current.append(sql[next!])
                    index = sql.index(after: next!)
                    continue
                }
                if ch == "*" && next != nil && sql[next!] == "/" {
                    blockCommentDepth -= 1
                    current.append(sql[next!])
                    index = sql.index(after: next!)
                    continue
                }
                index = sql.index(after: index)
                continue
            }

            // 字符串字面量状态
            if let quote = inString {
                current.append(ch)
                if ch == quote {
                    // 转义：两个连续引号
                    if let n = next, n < sql.endIndex, sql[n] == quote {
                        current.append(sql[n])
                        index = sql.index(after: n)
                        continue
                    }
                    inString = nil
                }
                index = sql.index(after: index)
                continue
            }

            // 进入字符串
            if ch == "'" || ch == "\"" || ch == "`" {
                inString = ch
                current.append(ch)
                index = sql.index(after: index)
                continue
            }

            // 进入行注释
            if ch == "-" && next != nil && sql[next!] == "-" {
                inLineComment = true
                current.append(ch)
                index = sql.index(after: index)
                continue
            }

            // 进入块注释
            if ch == "/" && next != nil && sql[next!] == "*" {
                blockCommentDepth = 1
                current.append(ch)
                current.append(sql[next!])
                index = sql.index(after: next!)
                continue
            }

            // 语句分隔符
            if ch == ";" {
                commitCurrentStatement()
                index = sql.index(after: index)
                continue
            }

            current.append(ch)
            index = sql.index(after: index)
        }

        // 收尾：最后一段（可能没有尾部分号）
        commitCurrentStatement()
        return result
    }

    /// 剥离字符串字面量、注释与带引号标识符，只保留「代码骨架」。
    ///
    /// 用于只读策略判定：安全检查关心的是**代码里出现了什么**，
    /// 而不是文本内容里出现了什么。
    /// `SELECT 'DROP' AS word` 的骨架是 `SELECT  AS word` —— 里面没有写操作；
    /// `SELECT * FROM t WHERE x = DROP()` 的骨架里 `DROP` 仍是裸关键字，仍会被拦下。
    ///
    /// 尊重的语法与 ``split(_:)`` 一致：
    /// - 单引号字符串字面量（含 `''` 转义）
    /// - 双引号标识符（含 `""` 转义）
    /// - 反引号标识符（MySQL，含 `` `` `` 转义）
    /// - 行注释（`--` 到行尾）与块注释（`/* ... */`，可嵌套）
    public static func stripLiteralsAndComments(_ sql: String) -> String {
        var result = ""
        var index = sql.startIndex
        var inString: Character? = nil
        var inLineComment = false
        var blockCommentDepth = 0

        while index < sql.endIndex {
            let ch = sql[index]
            let next = Self.nextIndex(in: sql, after: index)

            if inLineComment {
                if ch == "\n" {
                    inLineComment = false
                    result.append(ch)
                }
                index = sql.index(after: index)
                continue
            }

            if blockCommentDepth > 0 {
                if ch == "/" && next != nil && sql[next!] == "*" {
                    blockCommentDepth += 1
                    index = sql.index(after: next!)
                    continue
                }
                if ch == "*" && next != nil && sql[next!] == "/" {
                    blockCommentDepth -= 1
                    index = sql.index(after: next!)
                    continue
                }
                index = sql.index(after: index)
                continue
            }

            if let quote = inString {
                if ch == quote {
                    // 转义：两个连续引号
                    if let n = next, n < sql.endIndex, sql[n] == quote {
                        index = sql.index(after: n)
                        continue
                    }
                    inString = nil
                }
                index = sql.index(after: index)
                continue
            }

            // 进入字符串 / 标识符：整段丢弃，只留一个空格占位。
            if ch == "\'" || ch == "\"" || ch == "`" {
                inString = ch
                result.append(" ")
                index = sql.index(after: index)
                continue
            }

            // 进入行注释
            if ch == "-" && next != nil && sql[next!] == "-" {
                inLineComment = true
                index = sql.index(after: index)
                continue
            }

            // 进入块注释
            if ch == "/" && next != nil && sql[next!] == "*" {
                blockCommentDepth = 1
                index = sql.index(after: next!)
                continue
            }

            result.append(ch)
            index = sql.index(after: index)
        }

        return result
    }
}
