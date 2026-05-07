import Foundation

/// Go 构建问题（error / warning）
struct GoBuildIssue: Identifiable, Sendable {
    let id = UUID()
    /// 文件路径
    let file: String
    /// 行号
    let line: Int
    /// 列号
    let column: Int
    /// 严重程度
    let severity: Severity
    /// 消息
    let message: String

    enum Severity: String, Sendable {
        case error
        case warning
    }

    /// 从 go build 输出行解析构建问题
    ///
    /// 格式示例：`main.go:10:2: error: undefined: foo`
    /// 或：`main.go:10:2: undefined: foo`（无 severity 前缀时默认为 error）
    static func parse(from line: String) -> GoBuildIssue? {
        // 匹配模式：file:line:col: severity: message
        let pattern = #"^(.+?):(\d+):(\d+):\s*(error|warning):\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range) else {
            // 尝试无 severity 前缀的模式：file:line:col: message
            return parseWithoutSeverity(from: line)
        }

        let file = String(line[Range(match.range(at: 1), in: line)!])
        let lineNum = Int(String(line[Range(match.range(at: 2), in: line)!])) ?? 0
        let col = Int(String(line[Range(match.range(at: 3), in: line)!])) ?? 0
        let severityStr = String(line[Range(match.range(at: 4), in: line)!])
        let message = String(line[Range(match.range(at: 5), in: line)!])

        return GoBuildIssue(
            file: file,
            line: lineNum,
            column: col,
            severity: severityStr == "warning" ? .warning : .error,
            message: message
        )
    }

    /// 解析无 severity 前缀的行
    private static func parseWithoutSeverity(from line: String) -> GoBuildIssue? {
        let pattern = #"^(.+?):(\d+):(\d+):\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range) else { return nil }

        let file = String(line[Range(match.range(at: 1), in: line)!])
        let lineNum = Int(String(line[Range(match.range(at: 2), in: line)!])) ?? 0
        let col = Int(String(line[Range(match.range(at: 3), in: line)!])) ?? 0
        let message = String(line[Range(match.range(at: 4), in: line)!])

        // 过滤掉包路径行（以 # 开头）和空行
        guard !file.hasPrefix("#"), !message.isEmpty else { return nil }

        return GoBuildIssue(
            file: file,
            line: lineNum,
            column: col,
            severity: .error,
            message: message
        )
    }
}
