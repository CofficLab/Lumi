import Testing
import Foundation
@testable import ProjectIssueScannerPlugin

@Test func localRuleScannerOnlyReportsTodoMarkersFromComments() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("issue-scanner-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let source = """
    let todoValue = "not a marker"
    let message = "TODO: this is user-facing text, not a comment"
    // TODO: wire up the final action
    /* FIXME: handle error details */
    """
    try source.write(to: root.appendingPathComponent("Example.swift"), atomically: true, encoding: .utf8)

    let issues = LocalRuleScanner().scan(projectPath: root.path)

    #expect(issues.map(\.type) == [.todo, .fixme])
    #expect(issues.map(\.lineNumber) == [3, 4])
}

@Test func localRuleScannerDoesNotMatchTodoInsideLongerWords() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("issue-scanner-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let source = """
    // notodo should not be treated as a marker
    // TODO(later): this is a marker
    """
    try source.write(to: root.appendingPathComponent("Example.swift"), atomically: true, encoding: .utf8)

    let issues = LocalRuleScanner().scan(projectPath: root.path)

    #expect(issues.count == 1)
    #expect(issues.first?.type == .todo)
    #expect(issues.first?.lineNumber == 2)
}

@Test func localRuleScannerReadsUTF16SourceFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("issue-scanner-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let source = """
    struct Example {
        func run() {
            // FIXME: handle localized source files
        }
    }
    """
    try source.write(to: root.appendingPathComponent("Example.swift"), atomically: true, encoding: .utf16)

    let issues = LocalRuleScanner().scan(projectPath: root.path)

    #expect(issues.count == 1)
    #expect(issues.first?.type == .fixme)
    #expect(issues.first?.lineNumber == 3)
    #expect(issues.first?.description == "FIXME: handle localized source files")
}

@Test func relativePathRequiresProjectDirectoryBoundary() {
    let projectURL = URL(fileURLWithPath: "/tmp/Lumi")

    #expect(
        ProjectIssuePathFormatter.relativePath(
            for: URL(fileURLWithPath: "/tmp/Lumi/Sources/App.swift"),
            rootURL: projectURL
        ) == "Sources/App.swift"
    )
    #expect(
        ProjectIssuePathFormatter.relativePath(
            for: URL(fileURLWithPath: "/tmp/Lumi-Other/Sources/App.swift"),
            rootURL: projectURL
        ) == "/tmp/Lumi-Other/Sources/App.swift"
    )
}

@Test func scannerModelPreferenceRemovesCorruptStoredData() throws {
    let suiteName = "ProjectIssueScannerTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }
    defaults.set(Data("not json".utf8), forKey: ScannerModelPreference.userDefaultsKey)

    let preference = ScannerModelPreference.load(from: defaults)

    #expect(preference == .auto)
    #expect(defaults.data(forKey: ScannerModelPreference.userDefaultsKey) == nil)
}

@Test func scannerModelPreferenceSavesAndLoadsManualSelection() throws {
    let suiteName = "ProjectIssueScannerTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }
    let preference = ScannerModelPreference.manual(providerId: "openai", model: "gpt-5")

    #expect(preference.save(to: defaults))
    #expect(ScannerModelPreference.load(from: defaults) == preference)
}

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

@Test func projectIssueStoreDeduplicatesPersistedIssues() async throws {
    let firstIssue = makeProjectIssue(
        id: UUID(uuidString: "7F3C2345-AB40-4B14-9F8D-B2BD33E13190")!,
        status: .confirmed,
        updatedAt: Date(timeIntervalSince1970: 1_775_235_600)
    )
    let duplicateIssue = makeProjectIssue(
        id: UUID(uuidString: "A9E78102-1550-46B6-9A2B-00C06E510265")!,
        status: .pending,
        updatedAt: Date(timeIntervalSince1970: 1_775_239_200)
    )
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let data = try ProjectIssueStore.makeEncoder().encode([firstIssue, duplicateIssue])
    try data.write(to: tempURL)

    let store = ProjectIssueStore(issuesFileURL: tempURL)

    let loadedIssues = await store.fetchAll()
    #expect(loadedIssues.count == 1)
    #expect(loadedIssues.first?.id == firstIssue.id)

    try await store.replaceIssues(
        projectPath: firstIssue.projectPath,
        source: firstIssue.source,
        with: [
            makeProjectIssue(
                id: UUID(uuidString: "B9117F6C-36EF-423B-B902-F7AE464BA5F3")!,
                status: .pending,
                title: "Updated issue"
            )
        ]
    )

    let savedIssues = try ProjectIssueStore.loadFromDisk(from: tempURL)
    #expect(savedIssues.count == 1)
    #expect(savedIssues.first?.status == .confirmed)
    #expect(savedIssues.first?.title == "Updated issue")
}

@Test func projectIssueStoreNonPositiveLimitReturnsNoIssues() async throws {
    let issue = makeProjectIssue(projectPath: "/tmp/project-limit")
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let data = try ProjectIssueStore.makeEncoder().encode([issue])
    try data.write(to: tempURL)
    let store = ProjectIssueStore(issuesFileURL: tempURL)

    let zeroLimitIssues = await store.fetchOpen(projectPath: issue.projectPath, limit: 0)
    let negativeLimitIssues = await store.fetchOpen(projectPath: issue.projectPath, limit: -5)

    #expect(zeroLimitIssues.isEmpty)
    #expect(negativeLimitIssues.isEmpty)
}

private func makeProjectIssue(
    id: UUID = UUID(),
    status: ProjectIssueStatus = .pending,
    projectPath: String = "/tmp/project",
    title: String = "Empty catch block",
    updatedAt: Date = Date(timeIntervalSince1970: 1_775_232_000)
) -> ProjectIssue {
    ProjectIssue(
        id: id,
        type: .emptyCatch,
        severity: .warning,
        status: status,
        projectPath: projectPath,
        filePath: "Sources/App.swift",
        lineNumber: 42,
        title: title,
        description: "A catch block swallows errors.",
        suggestion: "Handle or log the error.",
        source: .localRule,
        createdAt: Date(timeIntervalSince1970: 1_775_232_000),
        updatedAt: updatedAt
    )
}
