import Testing
import Foundation
@testable import CodeReviewPlugin

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@Test func reviewAnalyzerReadsUTF16ProjectRules() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("code-review-\(UUID().uuidString)", isDirectory: true)
    let rulesDirectory = root.appendingPathComponent(".agent/rules", isDirectory: true)
    try FileManager.default.createDirectory(at: rulesDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try runGit(root: root, arguments: ["init"])
    let rules = """
    # Review Rules

    Always verify localized source handling.
    """
    try rules.write(
        to: rulesDirectory.appendingPathComponent("review.md"),
        atomically: true,
        encoding: .utf16
    )

    let context = try await ReviewAnalyzer().buildContext(repositoryPath: root.path, scope: .allUncommitted)

    #expect(context.projectRules.contains("## .agent/rules/review.md"))
    #expect(context.projectRules.contains("Always verify localized source handling."))
}

@Test func reviewGitServiceHandlesLargeDiffOutput() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("code-review-large-diff-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try runGit(root: root, arguments: ["init"])

    let fileURL = root.appendingPathComponent("Large.txt")
    let originalLine = "before " + String(repeating: "x", count: 512)
    try Array(repeating: originalLine, count: 300)
        .joined(separator: "\n")
        .write(to: fileURL, atomically: true, encoding: .utf8)
    try runGit(root: root, arguments: ["add", "Large.txt"])

    let changedLine = "after " + String(repeating: "y", count: 512)
    try Array(repeating: changedLine, count: 300)
        .joined(separator: "\n")
        .write(to: fileURL, atomically: true, encoding: .utf8)

    let diff = try ReviewGitService.shared.getDiff(path: root.path, staged: false, file: nil)

    #expect(diff.content.contains("-before "))
    #expect(diff.content.contains("+after "))
    #expect(diff.stats?.filesChanged == 1)
    #expect(diff.stats?.insertions == 300)
    #expect(diff.stats?.deletions == 300)
}

private func runGit(root: URL, arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments
    process.currentDirectoryURL = root

    let errorPipe = Pipe()
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: data, encoding: .utf8) ?? "git failed"
        throw NSError(domain: "PluginCodeReviewTests", code: Int(process.terminationStatus), userInfo: [
            NSLocalizedDescriptionKey: message
        ])
    }
}
