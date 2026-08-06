import Testing
import Foundation

/// Walks the plugin `Sources/` directory and asserts the disabled scaffold
/// build contains none of the symbols the architecture decision record
/// forbids: SwiftUI `NSHostingView`, the SwiftUI MarkdownKit renderer, or
/// the legacy `MessageRowView`.
///
/// Fails fast if a future change accidentally re-introduces them before the
/// native rendering pipeline is in place.
///
/// Uses whole-word matching so that comments like
/// `// host the bridge via NSViewControllerRepresentable` (which contains
/// the substring `NSHost`) do not raise false positives, and so that a
/// renamed symbol (e.g. `MyNSHostingViewWrapper`) cannot evade detection
/// by changing the substring without changing the identifier.
@Suite("MessageListAppKitPlugin.SourceBoundary")
struct SourceBoundaryTests {
    /// Symbols that must never appear anywhere under `Sources/` as
    /// identifier-shaped tokens.
    private static let forbidden: [String] = [
        "NSHostingView",
        "MarkdownBlockRenderer",
        "MessageRowView",
    ]

    /// Regex matching `.product(name: "MarkdownKit", …)` — SwiftPM's named
    /// product form for the SwiftUI renderer library. Comments are free
    /// to mention "MarkdownKit" (e.g. to explain why we don't use it),
    /// but a declared SwiftPM product with that exact name would defeat
    /// the boundary by re-introducing the SwiftUI renderer.
    private static let forbiddenDependencyPattern: String =
        #"\.product\s*\(\s*name\s*:\s*"MarkdownKit""#

    private static let identifierRegex: NSRegularExpression = {
        let escaped = forbidden.map(Self.escape(_:)).joined(separator: "|")
        return try! NSRegularExpression(pattern: "\\b(?:\(escaped))\\b")
    }()

    private static let dependencyRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: forbiddenDependencyPattern)
    }()

    private static func escape(_ symbol: String) -> String {
        NSRegularExpression.escapedPattern(for: symbol)
    }

    @Test("Sources/ does not host SwiftUI views, SwiftUI MarkdownKit renderer, or legacy MessageRowView")
    func noForbiddenSymbols() throws {
        let sourcesURL = try Self.sourcesDirectory()
        let files = try collectSwiftFiles(under: sourcesURL)

        #expect(!files.isEmpty, "no Swift files found under \(sourcesURL.path)")

        var violations: [String] = []

        for file in files {
            let contents = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(contents.startIndex..., in: contents)
            for match in Self.identifierRegex.matches(in: contents, range: range) {
                let symbol = (contents as NSString).substring(with: match.range)
                violations.append("\(file.lastPathComponent): contains forbidden identifier `\(symbol)`")
            }
        }

        #expect(
            violations.isEmpty,
            Comment(rawValue: "Source boundary violations:\n" + violations.joined(separator: "\n"))
        )
    }

    @Test("Package.swift never pulls in the SwiftUI MarkdownKit product")
    func noMarkdownKitProductDependency() throws {
        let packageURL = try Self.packageManifest()
        let contents = try String(contentsOf: packageURL, encoding: .utf8)
        let range = NSRange(contents.startIndex..., in: contents)

        var violations: [String] = []
        for match in Self.dependencyRegex.matches(in: contents, range: range) {
            violations.append("\(packageURL.lastPathComponent): forbidden `.product(name: \"MarkdownKit\", …)` at offset \(match.range.location)")
        }

        #expect(
            violations.isEmpty,
            Comment(rawValue: "Dependency boundary violations:\n" + violations.joined(separator: "\n"))
        )
    }

    // MARK: - Helpers

    private static func sourcesDirectory() throws -> URL {
        try pluginRoot().appendingPathComponent("Sources", isDirectory: true)
    }

    private static func packageManifest() throws -> URL {
        try pluginRoot().appendingPathComponent("Package.swift", isDirectory: false)
    }

    private static func pluginRoot() throws -> URL {
        // thisFile: .../Tests/MessageListAppKitPluginTests/SourceBoundaryTests.swift
        let thisFile = URL(fileURLWithPath: #filePath)
        return thisFile
            .deletingLastPathComponent() // Tests/MessageListAppKitPluginTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Plugin root
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
