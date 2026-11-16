import Foundation

/// MCP stdio 参数在编辑框里以单行文本呈现，需要可逆的「拼接 ↔ 拆分」。
///
/// 直接按空格拼接/拆分会把含空格的单个参数（如 `/tmp/My Project`）拆成多个，
/// 仅改名字再保存也会破坏未编辑的参数边界（#534）。这里用 shell 风格的引号规则
/// 保证 `parse(join(args)) == args`：含空白或引号/反斜杠的参数用双引号包裹并转义
/// 内部的 `"` 与 `\`；解析时识别单/双引号与反斜杠转义，引号内空白按字面保留。
enum MCPArgumentsCodec {
    /// 把参数数组拼成可逆的单行文本。
    static func join(_ arguments: [String]) -> String {
        arguments.map(quote).joined(separator: " ")
    }

    /// 把单行文本拆回参数数组，识别引号与转义，保留参数内部空白。
    static func parse(_ text: String) -> [String] {
        let chars = Array(text)
        var tokens: [String] = []
        var current = ""
        // 空引号 "" 也要产出一个空字符串参数，故用独立标志而非 current.isEmpty。
        var hasToken = false
        var inDouble = false
        var inSingle = false
        var i = 0

        while i < chars.count {
            let c = chars[i]
            if inSingle {
                if c == "'" { inSingle = false } else { current.append(c) }
                i += 1
                continue
            }
            if inDouble {
                if c == "\"" {
                    inDouble = false
                    i += 1
                } else if c == "\\" {
                    // 双引号内只转义 " 与 \，其余反斜杠按字面保留。
                    if i + 1 < chars.count, chars[i + 1] == "\"" || chars[i + 1] == "\\" {
                        current.append(chars[i + 1])
                        i += 2
                    } else {
                        current.append(c)
                        i += 1
                    }
                } else {
                    current.append(c)
                    i += 1
                }
                continue
            }
            if c.isWhitespace {
                if hasToken {
                    tokens.append(current)
                    current = ""
                    hasToken = false
                }
                i += 1
                continue
            }
            hasToken = true
            if c == "\"" {
                inDouble = true
                i += 1
            } else if c == "'" {
                inSingle = true
                i += 1
            } else if c == "\\" {
                if i + 1 < chars.count {
                    current.append(chars[i + 1])
                    i += 2
                } else {
                    current.append(c)
                    i += 1
                }
            } else {
                current.append(c)
                i += 1
            }
        }
        if hasToken { tokens.append(current) }
        return tokens
    }

    /// 含空白或引号/反斜杠的参数用双引号包裹并转义，其余原样输出。
    private static func quote(_ argument: String) -> String {
        if argument.isEmpty { return "\"\"" }
        let needsQuoting = argument.contains {
            $0.isWhitespace || $0 == "\"" || $0 == "'" || $0 == "\\"
        }
        guard needsQuoting else { return argument }
        var escaped = ""
        for c in argument {
            if c == "\"" || c == "\\" { escaped.append("\\") }
            escaped.append(c)
        }
        return "\"" + escaped + "\""
    }
}