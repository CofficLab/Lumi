import Testing
import Foundation
@testable import PluginProjectIssueScanner

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
