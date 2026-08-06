import Testing
import Foundation

/// Walks the plugin `Sources/` directory and asserts the disabled scaffold
/// build contains none of the symbols the architecture decision record
/// forbids: SwiftUI `NSHostingView`, the SwiftUI MarkdownKit renderer, or
/// the legacy `MessageRowView`.
///
/// Fails fast if a future change accidentally re-introduces them before the
/// native rendering pipeline is in place.
@Suite("MessageListAppKitPlugin.SourceBoundary")
struct SourceBoundaryTests {
    /// Symbols that must never appear anywhere under `Sources/`.
    private static let forbidden: [String] = [
        "NSHostingView",
        "MarkdownBlockRenderer",
        "MessageRowView",
    ]

    @Test("Sources/ does not host SwiftUI views, SwiftUI MarkdownKit renderer, or legacy MessageRowView")
    func noForbiddenSymbols() throws {
        let sourcesURL = try Self.sourcesDirectory()
        let files = try collectSwiftFiles(under: sourcesURL)

        #expect(!files.isEmpty, "no Swift files found under \(sourcesURL.path)")

        var violations: [String] = []

        for file in files {
            let contents = try String(contentsOf: file, encoding: .utf8)
            for symbol in Self.forbidden {
                if contents.contains(symbol) {
                    violations.append("\(file.lastPathComponent): contains forbidden symbol `\(symbol)`")
                }
            }
        }

        #expect(
            violations.isEmpty,
            Comment(rawValue: "Source boundary violations:\n" + violations.joined(separator: "\n"))
        )
    }

    // MARK: - Helpers

    private static func sourcesDirectory() throws -> URL {
        let thisFile = URL(fileURLWithPath: #filePath)
        // thisFile: .../Tests/MessageListAppKitPluginTests/SourceBoundaryTests.swift
        let testsDir = thisFile.deletingLastPathComponent()
        let testsTarget = testsDir.deletingLastPathComponent()
        let tests = testsTarget.deletingLastPathComponent()
        return tests.appendingPathComponent("Sources", isDirectory: true)
    }

    private func collectSwiftFiles(under root: URL) throws -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var result: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            if url.pathExtension == "swift" {
                result.append(url)
            }
        }
        return result
    }
}
