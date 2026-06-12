import Foundation

public struct JSBuildIssue: Identifiable, Sendable {
    public let id = UUID()
    public let file: String
    public let line: Int
    public let column: Int
    public let severity: Severity
    public let message: String
    public let source: String

    public enum Severity: String, Sendable {
        case error
        case warning
    }

    public static func parse(from line: String) -> JSBuildIssue? {
        let patterns = [
            #"^(.+?):(\d+):(\d+)\s+-\s+(error|warning)\s+(.+)$"#,
            #"^(.+?)\((\d+),(\d+)\):\s+(error|warning)\s+(.+)$"#,
            #"^(.+?):(\d+):(\d+):\s+(error|warning):\s+(.+)$"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range),
                  match.numberOfRanges >= 6,
                  let fileRange = Range(match.range(at: 1), in: line),
                  let lineRange = Range(match.range(at: 2), in: line),
                  let columnRange = Range(match.range(at: 3), in: line),
                  let severityRange = Range(match.range(at: 4), in: line),
                  let messageRange = Range(match.range(at: 5), in: line) else {
                continue
            }

            let severityText = String(line[severityRange]).lowercased()
            return JSBuildIssue(
                file: String(line[fileRange]),
                line: Int(line[lineRange]) ?? 0,
                column: Int(line[columnRange]) ?? 0,
                severity: severityText == "warning" ? .warning : .error,
                message: String(line[messageRange]),
                source: line
            )
        }

        return nil
    }
}
