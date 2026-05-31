import Testing
import Foundation
@testable import PluginProjectIssueScanner

@Test func projectIssueStoreLoadsPersistedISO8601Dates() throws {
    let issue = ProjectIssue(
        id: UUID(uuidString: "2E87F59C-1C80-49A8-84D7-0546F43B28C1")!,
        type: .emptyCatch,
        severity: .warning,
        status: .confirmed,
        projectPath: "/tmp/project",
        filePath: "Sources/App.swift",
        lineNumber: 42,
        title: "Empty catch block",
        description: "A catch block swallows errors.",
        suggestion: "Handle or log the error.",
        source: .localRule,
        createdAt: Date(timeIntervalSince1970: 1_775_232_000),
        updatedAt: Date(timeIntervalSince1970: 1_775_235_600)
    )
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let data = try ProjectIssueStore.makeEncoder().encode([issue])
    try data.write(to: tempURL)

    let loadedIssues = try ProjectIssueStore.loadFromDisk(from: tempURL)

    #expect(loadedIssues.count == 1)
    #expect(loadedIssues.first?.id == issue.id)
    #expect(loadedIssues.first?.status == .confirmed)
    #expect(loadedIssues.first?.createdAt == issue.createdAt)
    #expect(loadedIssues.first?.updatedAt == issue.updatedAt)
}
