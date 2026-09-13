import Foundation
import KitAgentTool
import Testing
@testable import PluginDocxRead

@Test func toolMetadataDescribesRequiredPathAndLowRiskRead() {
    let tool = DocxReadTool()
    let schema = tool.inputSchema(for: LanguagePreference.english)
    let properties = schema["properties"] as? [String: Any]
    let path = properties?["path"] as? [String: Any]
    let required = schema["required"] as? [String]

    #expect(tool.name == "read_docx")
    #expect(tool.description(for: .english).contains("DOCX"))
    #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
    #expect(tool.displayDescription(for: [:]) == "读取 DOCX")
    #expect(tool.displayDescription(for: ["path": ToolArgument("/documents/Report.docx")]) == "读取 Report.docx")
    #expect(schema["type"] as? String == "object")
    #expect(path?["type"] as? String == "string")
    #expect(required == ["path"])
}

@Test func executeRejectsMissingPathAndReturnsReadableMissingFileError() async throws {
    let tool = DocxReadTool(extractText: { _ in throw StubExtractionError.unexpectedInvocation })

    do {
        _ = try await tool.execute(arguments: [:])
        Issue.record("Expected a missing path error")
    } catch let error as NSError {
        #expect(error.domain == "DocxReadTool")
        #expect(error.code == 400)
        #expect(error.localizedDescription == "Missing 'path' argument")
    }

    let result = try await tool.execute(arguments: ["path": ToolArgument("~/codex-missing.docx")])
    let expandedPath = ("~/codex-missing.docx" as NSString).expandingTildeInPath
    #expect(result == "Error: File not found at path: \(expandedPath)")
}

@Test func executeReturnsExtractedAndEmptyDocumentContent() async throws {
    let documentURL = temporaryDocumentURL()
    try Data().write(to: documentURL)
    defer { try? FileManager.default.removeItem(at: documentURL) }

    let tool = DocxReadTool(extractText: { _ in "Extracted document text" })
    let result = try await tool.execute(arguments: ["path": ToolArgument(documentURL.path)])
    #expect(result == "Extracted document text")

    let emptyTool = DocxReadTool(extractText: { _ in "" })
    let emptyResult = try await emptyTool.execute(arguments: ["path": ToolArgument(documentURL.path)])
    #expect(emptyResult == "(empty DOCX)")
}

@Test func executePropagatesExtractionErrors() async throws {
    let documentURL = temporaryDocumentURL()
    try Data().write(to: documentURL)
    defer { try? FileManager.default.removeItem(at: documentURL) }
    let tool = DocxReadTool(extractText: { _ in throw StubExtractionError.failed })

    do {
        _ = try await tool.execute(arguments: ["path": ToolArgument(documentURL.path)])
        Issue.record("Expected extraction failure to propagate")
    } catch let error as StubExtractionError {
        #expect(error == .failed)
    }
}

#if os(macOS)
@Test func systemTextutilExtractsAValidDocxFile() async throws {
    let sourceURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("DocxReadToolTests-\(UUID().uuidString).txt")
    let documentURL = sourceURL.deletingPathExtension().appendingPathExtension("docx")
    try "DOCX extraction works".write(to: sourceURL, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: sourceURL)
        try? FileManager.default.removeItem(at: documentURL)
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
    process.arguments = ["-convert", "docx", "-output", documentURL.path, sourceURL.path]
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)

    let result = try await DocxReadTool().execute(arguments: ["path": ToolArgument(documentURL.path)])
    #expect(result.contains("DOCX extraction works"))
}

@Test func systemTextutilReturnsEmptyContentForAnEmptyDocxFile() async throws {
    let documentURL = temporaryDocumentURL()
    try Data().write(to: documentURL)
    defer { try? FileManager.default.removeItem(at: documentURL) }

    let result = try await DocxReadTool().execute(arguments: ["path": ToolArgument(documentURL.path)])
    #expect(result == "(empty DOCX)")
}
#endif

private func temporaryDocumentURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("DocxReadToolTests-\(UUID().uuidString).docx")
}

private enum StubExtractionError: Error, Equatable, Sendable {
    case failed
    case unexpectedInvocation
}
