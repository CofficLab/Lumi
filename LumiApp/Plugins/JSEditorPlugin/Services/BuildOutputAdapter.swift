import Foundation

enum BuildOutputAdapter {
    static func outputLines(stdout: String, stderr: String) -> [String] {
        (stderr + stdout)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func issues(stdout: String, stderr: String) -> [JSBuildIssue] {
        outputLines(stdout: stdout, stderr: stderr).compactMap(JSBuildIssue.parse)
    }
}
