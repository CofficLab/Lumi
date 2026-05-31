import Foundation

public enum BuildOutputAdapter {
    public static func outputLines(stdout: String, stderr: String) -> [String] {
        combinedOutput(stdout: stdout, stderr: stderr)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public static func issues(stdout: String, stderr: String) -> [JSBuildIssue] {
        outputLines(stdout: stdout, stderr: stderr).compactMap(JSBuildIssue.parse)
    }

    static func combinedOutput(stdout: String, stderr: String) -> String {
        guard !stderr.isEmpty else { return stdout }
        guard !stdout.isEmpty else { return stderr }
        guard stderr.unicodeScalars.last.map(CharacterSet.newlines.contains) != true else {
            return stderr + stdout
        }
        return stderr + "\n" + stdout
    }
}
