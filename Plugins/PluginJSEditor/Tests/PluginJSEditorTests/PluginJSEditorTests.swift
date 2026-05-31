import Testing
import Foundation
@testable import PluginJSEditor

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func tsConfigResolverParsesJSONCCommentsAndTrailingCommas() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let configURL = directory.appendingPathComponent("tsconfig.json")
    try """
    {
      // Common in tsconfig files generated or edited by users.
      "compilerOptions": {
        "baseUrl": ".",
        "paths": {
          "@/*": ["src/*"],
        },
        "jsx": "react-jsx",
        "strict": true,
      },
    }
    """.write(to: configURL, atomically: true, encoding: .utf8)

    let config = try #require(TSConfigResolver.parse(fileURL: configURL))

    #expect(config.baseURL == ".")
    #expect(config.paths["@/*"] == ["src/*"])
    #expect(config.jsx == "react-jsx")
    #expect(config.strict == true)
}

@Test func tsConfigResolverKeepsCommentMarkersInsideStrings() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let configURL = directory.appendingPathComponent("jsconfig.json")
    try #"""
    {
      "compilerOptions": {
        "baseUrl": "https://example.com/project",
        "paths": {
          "/*": ["src/*,literal"],
        }
      }
    }
    """#.write(to: configURL, atomically: true, encoding: .utf8)

    let config = try #require(TSConfigResolver.parse(fileURL: configURL))

    #expect(config.baseURL == "https://example.com/project")
    #expect(config.paths["/*"] == ["src/*,literal"])
}

@Test func sourceMapResolverUsesLastMappingURLMarker() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let generatedURL = directory.appendingPathComponent("bundle.js")
    try """
    const text = "sourceMappingURL=wrong.map";
    //# sourceMappingURL=bundle.js.map
    """.write(to: generatedURL, atomically: true, encoding: .utf8)

    let sourceMapURL = try #require(SourceMapResolver.sourceMapURL(for: generatedURL))

    #expect(sourceMapURL.lastPathComponent == "bundle.js.map")
}

@Test func sourceMapResolverResolvesRelativeMappingURLAgainstGeneratedFile() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let generatedURL = directory.appendingPathComponent("dist/bundle.js")
    try FileManager.default.createDirectory(at: generatedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try """
    console.log("ready");
    //# sourceMappingURL=maps/bundle.js.map
    """.write(to: generatedURL, atomically: true, encoding: .utf8)

    let sourceMapURL = try #require(SourceMapResolver.sourceMapURL(for: generatedURL))

    #expect(sourceMapURL.isFileURL)
    #expect(sourceMapURL.path == generatedURL.deletingLastPathComponent().appendingPathComponent("maps/bundle.js.map").path)
}

@Test func sourceMapResolverReadsMappingURLFromUTF16GeneratedFile() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let generatedURL = directory.appendingPathComponent("dist/bundle.js")
    try FileManager.default.createDirectory(at: generatedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try """
    console.log("ready");
    //# sourceMappingURL=maps/bundle.js.map
    """.write(to: generatedURL, atomically: true, encoding: .utf16)

    let sourceMapURL = try #require(SourceMapResolver.sourceMapURL(for: generatedURL))

    #expect(sourceMapURL.path == generatedURL.deletingLastPathComponent().appendingPathComponent("maps/bundle.js.map").path)
}

@Test func sourceMapResolverKeepsAbsoluteMappingURL() throws {
    let generatedURL = URL(fileURLWithPath: "/tmp/dist/bundle.js")

    let sourceMapURL = try #require(SourceMapResolver.resolveSourceMapTail("https://example.com/bundle.js.map", relativeTo: generatedURL))

    #expect(sourceMapURL.absoluteString == "https://example.com/bundle.js.map")
}

@Test func sourceMapResolverKeepsQuotedMappingURLWithSpaces() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("JSEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let generatedURL = directory.appendingPathComponent("dist/bundle.js")
    try FileManager.default.createDirectory(at: generatedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try """
    console.log("ready");
    //# sourceMappingURL="maps/bundle debug.js.map"
    """.write(to: generatedURL, atomically: true, encoding: .utf8)

    let sourceMapURL = try #require(SourceMapResolver.sourceMapURL(for: generatedURL))

    #expect(sourceMapURL.path == generatedURL.deletingLastPathComponent().appendingPathComponent("maps/bundle debug.js.map").path)
}

@Test func sourceMapResolverAcceptsUnescapedFileURLMappingURLWithSpaces() throws {
    let generatedURL = URL(fileURLWithPath: "/tmp/dist/bundle.js")
    let sourceMapURL = try #require(SourceMapResolver.resolveSourceMapTail(
        "file:///tmp/project/My Map.js.map",
        relativeTo: generatedURL
    ))

    #expect(sourceMapURL.path == "/tmp/project/My Map.js.map")
}

@Test func buildOutputAdapterKeepsStdoutAndStderrLineBoundaryWithoutTrailingNewline() throws {
    let issues = BuildOutputAdapter.issues(
        stdout: "src/app.ts:2:3 - warning unused variable",
        stderr: "src/app.ts:1:1 - error missing semicolon"
    )

    #expect(issues.count == 2)
    #expect(issues.map(\.severity) == [.error, .warning])
    #expect(issues.map(\.line) == [1, 2])
}

@Test func testOutputParserKeepsStreamBoundaryWithoutTrailingNewline() throws {
    let output = BuildOutputAdapter.combinedOutput(
        stdout: "✓ renders dashboard (20ms)",
        stderr: "FAIL failing.test.ts"
    )

    let events = TestOutputParser.parse(output: output)

    #expect(events.count == 2)
    #expect(events.map(\.status) == [.failed, .passed])
    #expect(events.map(\.name) == ["failing.test.ts", "renders dashboard (20ms)"])
}

@Test func jsIssueFileResolverKeepsFileURLsAndExpandsLocalPaths() {
    let projectRoot = "/tmp/project"

    #expect(JSIssueFileResolver.url(for: "file:///tmp/project/src/app.ts", projectRoot: projectRoot).path == "/tmp/project/src/app.ts")
    #expect(JSIssueFileResolver.url(for: "file:///tmp/project/src/app with space.ts", projectRoot: projectRoot).path == "/tmp/project/src/app with space.ts")
    #expect(JSIssueFileResolver.url(for: "~/src/app.ts", projectRoot: projectRoot).path == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("src/app.ts").path)
    #expect(JSIssueFileResolver.url(for: "src/app.ts", projectRoot: projectRoot).path == "/tmp/project/src/app.ts")
}
