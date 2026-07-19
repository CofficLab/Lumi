import Foundation
import LumiKernel
import Testing
@testable import ToolCorePlugin

@Test func readFileLineReaderReturnsFullSmallFile() {
    let content = "alpha\nbeta\ngamma"
    let result = ReadFileLineReader.read(
        content: content,
        request: ReadFileLineReader.Request(offset: nil, limit: nil)
    )

    #expect(result.totalLines == 3)
    #expect(result.startLine == 1)
    #expect(result.endLine == 3)
    #expect(result.formattedContent == "1|alpha\n2|beta\n3|gamma")
}

@Test func readFileLineReaderTruncatesLargeFileByDefault() {
    let content = (1...300).map(String.init).joined(separator: "\n")
    let result = ReadFileLineReader.read(
        content: content,
        request: ReadFileLineReader.Request(offset: nil, limit: nil)
    )

    #expect(result.totalLines == 300)
    #expect(result.startLine == 1)
    #expect(result.endLine == 250)
    #expect(result.formattedContent.hasPrefix("  1|1\n  2|2"))
    #expect(result.formattedContent.contains("[Showing lines 1-250 of 300. Use offset=251 with limit to read more.]"))
}

@Test func readFileLineReaderSupportsOffsetAndLimit() {
    let content = (1...10).map(String.init).joined(separator: "\n")
    let result = ReadFileLineReader.read(
        content: content,
        request: ReadFileLineReader.Request(offset: 4, limit: 3)
    )

    #expect(result.startLine == 4)
    #expect(result.endLine == 6)
    #expect(result.formattedContent == " 4|4\n 5|5\n 6|6\n\n[Showing lines 4-6 of 10. Use offset=7 with limit to read more.]")
}

@Test func readFileLineReaderSupportsNegativeOffset() {
    let content = "one\ntwo\nthree"
    let result = ReadFileLineReader.read(
        content: content,
        request: ReadFileLineReader.Request(offset: -1, limit: 1)
    )

    #expect(result.startLine == 3)
    #expect(result.endLine == 3)
    #expect(result.formattedContent == "3|three")
}

@Test func readFileToolReadsChunkFromDisk() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ReadFileTool-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let fileURL = directory.appendingPathComponent("sample.txt")
    let lines = (1...20).map { "line \($0)" }
    try lines.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)

    let tool = ReadFileTool()
    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "call-1",
        toolName: tool.name,
        currentProjectPath: directory.path
    )

    let output = try await tool.execute(
        arguments: [
            "path": .string(fileURL.path),
            "offset": .int(5),
            "limit": .int(2)
        ],
        context: context
    )

    #expect(output == " 5|line 5\n 6|line 6\n\n[Showing lines 5-6 of 20. Use offset=7 with limit to read more.]")
}
