import Foundation

/// Parses xcodebuild / swift compiler diagnostics from build output.
public enum XcodeBuildIssueParser {

  private static let diagnosticPattern = #"(.+?):(\d+):(\d+):\s*(error|warning):\s*(.+)$"#

  public static func parse(stdout: String, stderr: String) -> (lines: [String], issues: [SwiftBuildIssue]) {
    let combined = [stdout, stderr]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")

    guard !combined.isEmpty else {
      return ([], [])
    }

    let rawLines = combined.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var issues: [SwiftBuildIssue] = []
    var seenIssueIDs = Set<String>()

    for line in rawLines {
      if let issue = parseDiagnosticLine(line), seenIssueIDs.insert(issue.id).inserted {
        issues.append(issue)
      }
    }

    return (rawLines, issues)
  }

  public static func failureSummary(stdout: String, stderr: String, exitCode: Int) -> String {
    let parsed = parse(stdout: stdout, stderr: stderr)
    if !parsed.issues.isEmpty {
      return parsed.issues.map { issue in
        if let file = issue.file, let line = issue.line {
          return "\(file):\(line): \(issue.message)"
        }
        return issue.message
      }.joined(separator: "\n")
    }

    let combined = [stderr, stdout]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")

    guard !combined.isEmpty else {
      return "Build failed with exit code \(exitCode)"
    }

    let errorLines = combined
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map(String.init)
      .filter { line in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("/") || !trimmed.contains("xcodebuild") else { return false }
        return trimmed.contains(": error:")
          || trimmed.hasPrefix("error:")
          || trimmed.contains("BUILD FAILED")
          || trimmed.contains("Undefined symbol")
      }

    if !errorLines.isEmpty {
      return errorLines.joined(separator: "\n")
    }

    return combined
  }

  private static func parseDiagnosticLine(_ line: String) -> SwiftBuildIssue? {
    guard let regex = try? NSRegularExpression(pattern: diagnosticPattern),
          let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
          let fileRange = Range(match.range(at: 1), in: line),
          let lineRange = Range(match.range(at: 2), in: line),
          let columnRange = Range(match.range(at: 3), in: line),
          let severityRange = Range(match.range(at: 4), in: line),
          let messageRange = Range(match.range(at: 5), in: line)
    else {
      return nil
    }

    let severityRaw = String(line[severityRange])
    let severity: SwiftBuildIssueSeverity = severityRaw == "warning" ? .warning : .error
    return SwiftBuildIssue(
      file: String(line[fileRange]),
      line: Int(line[lineRange]),
      column: Int(line[columnRange]),
      severity: severity,
      message: String(line[messageRange])
    )
  }
}
