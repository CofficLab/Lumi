import Testing
import Foundation
@testable import PluginCodeReview

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
