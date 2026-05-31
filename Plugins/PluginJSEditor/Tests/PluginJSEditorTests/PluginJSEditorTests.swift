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
