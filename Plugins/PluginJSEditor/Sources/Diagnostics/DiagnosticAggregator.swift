import Foundation

public enum DiagnosticAggregator {
    public static func aggregate(buildOutput: [String], eslintOutput: String?) -> [JSBuildIssue] {
        var issues = buildOutput.compactMap(JSBuildIssue.parse)
        if let eslintOutput {
            issues.append(contentsOf: eslintOutput.components(separatedBy: .newlines).compactMap(JSBuildIssue.parse))
        }
        return issues
    }
}
