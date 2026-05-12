import CryptoKit
import Foundation

/// Builds a small dynamic preview entry dylib for a discovered `#Preview`.
public final class PreviewEntryBuilder: Sendable {
    /// The C symbol exported by generated preview entry dylibs.
    public static let symbolName = "lumi_preview_entry"

    /// The C symbol dynamic preview dylibs can export to return a retained `NSView`.
    public static let viewSymbolName = "lumi_preview_make_nsview"

    private let incrementalCompiler: IncrementalCompiler
    private let spmCompiler: SPMCompiler
    private let xcodeCompiler: XcodeCompiler
    private let encoder = JSONEncoder()

    /// Creates a preview entry builder.
    public init(
        incrementalCompiler: IncrementalCompiler = IncrementalCompiler(),
        spmCompiler: SPMCompiler = SPMCompiler(),
        xcodeCompiler: XcodeCompiler = XcodeCompiler()
    ) {
        self.incrementalCompiler = incrementalCompiler
        self.spmCompiler = spmCompiler
        self.xcodeCompiler = xcodeCompiler
    }

    /// Generates, compiles, links, and signs a preview entry dylib.
    ///
    /// When target context is available, the generated entry is compiled with
    /// sanitized target sources so `#Preview` bodies can reference sibling files.
    public func buildEntry(
        for discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration,
        buildStrategy: BuildStrategy? = nil
    ) async throws -> URL {
        do {
            let generatedSources = try viewEntrySources(
                for: discovery,
                configuration: configuration,
                buildStrategy: buildStrategy
            )
            let compilerArguments = try await viewEntryCompilerArguments(for: buildStrategy)
            let fingerprint = Self.fingerprint(
                discovery: discovery,
                configuration: configuration,
                buildStrategy: buildStrategy,
                generatedSources: generatedSources,
                compilerArguments: compilerArguments
            )
            let directory = Self.cacheDirectory(for: fingerprint)
            let dylibURL = directory.appendingPathComponent("PreviewEntry.dylib")
            if FileManager.default.fileExists(atPath: dylibURL.path) {
                return dylibURL
            }

            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let viewSourceURLs = try write(generatedSources, to: directory)
            let dylib = try await incrementalCompiler.compileLibrary(
                sourceURLs: viewSourceURLs,
                dylibURL: dylibURL,
                compilerArguments: compilerArguments,
                moduleName: Self.moduleName(for: fingerprint)
            )
            try await incrementalCompiler.codesign(dylibURL: dylib)
            return dylib
        } catch {
            let fingerprint = Self.fallbackFingerprint(
                discovery: discovery,
                configuration: configuration,
                buildStrategy: buildStrategy,
                error: error
            )
            let directory = Self.cacheDirectory(for: fingerprint)
            let sourceURL = directory.appendingPathComponent("PreviewEntry.swift")
            let objectURL = directory.appendingPathComponent("PreviewEntry.o")
            let dylibURL = directory.appendingPathComponent("PreviewEntry.dylib")
            if FileManager.default.fileExists(atPath: dylibURL.path) {
                return dylibURL
            }

            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try descriptorEntrySource(
                for: discovery,
                configuration: configuration,
                viewEntryBuildError: Self.diagnosticMessage(from: error)
            ).write(to: sourceURL, atomically: true, encoding: .utf8)
            return try await compileEntry(sourceURL: sourceURL, objectURL: objectURL)
        }
    }

    private func compileEntry(sourceURL: URL, objectURL: URL) async throws -> URL {
        let objectFile = try await incrementalCompiler.compile(
            fileURL: sourceURL,
            compileCommand: "/usr/bin/env swiftc -c \(Self.shellQuoted(sourceURL.path)) -o \(Self.shellQuoted(objectURL.path))"
        )
        let dylibURL = try await incrementalCompiler.link(objectFileURL: objectFile)
        try await incrementalCompiler.codesign(dylibURL: dylibURL)

        return dylibURL
    }

    private static func cacheDirectory(for fingerprint: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-PreviewEntryCache", isDirectory: true)
            .appendingPathComponent(fingerprint, isDirectory: true)
    }

    private static func moduleName(for fingerprint: String) -> String {
        "LumiPreviewEntry_\(fingerprint.prefix(16))"
    }

    private static func fingerprint(
        discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration,
        buildStrategy: BuildStrategy?,
        generatedSources: [GeneratedSource],
        compilerArguments: [String]
    ) -> String {
        var parts: [String] = [
            "v2",
            discovery.id,
            discovery.sourceFileURL.standardizedFileURL.resolvingSymlinksInPath().path,
            "\(discovery.lineNumber)-\(discovery.endLineNumber)",
            discovery.primaryTypeName ?? "",
            String(describing: buildStrategy),
            configurationFingerprint(configuration),
            compilerArguments.joined(separator: "\u{1f}")
        ]
        for source in generatedSources.sorted(by: { $0.fileName < $1.fileName }) {
            parts.append(source.fileName)
            parts.append(source.content)
        }
        return sha256(parts.joined(separator: "\u{1e}"))
    }

    private static func fallbackFingerprint(
        discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration,
        buildStrategy: BuildStrategy?,
        error: Error
    ) -> String {
        sha256([
            "fallback-v2",
            discovery.id,
            discovery.sourceFileURL.standardizedFileURL.resolvingSymlinksInPath().path,
            "\(discovery.lineNumber)-\(discovery.endLineNumber)",
            discovery.bodySource ?? "",
            String(describing: buildStrategy),
            configurationFingerprint(configuration),
            diagnosticMessage(from: error)
        ].joined(separator: "\u{1e}"))
    }

    private static func configurationFingerprint(_ configuration: PreviewRenderConfiguration) -> String {
        guard let data = try? JSONEncoder().encode(configuration),
              let text = String(data: data, encoding: .utf8) else {
            return String(describing: configuration)
        }
        return text
    }

    private static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func viewEntryCompilerArguments(for buildStrategy: BuildStrategy?) async throws -> [String] {
        switch buildStrategy {
        case .spm(let packageDirectory, let targetName):
            return spmCompiler.previewCompilerArguments(packageDirectory: packageDirectory, targetName: targetName)
        case .xcode(let projectURL, let scheme, let configuration):
            return try await xcodeCompiler.previewCompilerArguments(
                projectURL: projectURL,
                scheme: scheme,
                configuration: configuration
            )
        case .incremental, .none:
            return []
        }
    }

    private struct GeneratedSource {
        let fileName: String
        let content: String
    }

    private func viewEntrySources(
        for discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration,
        buildStrategy: BuildStrategy?
    ) throws -> [GeneratedSource] {
        let targetSourceURLs = sourceFiles(for: discovery, buildStrategy: buildStrategy)
        var generatedSources: [GeneratedSource] = []
        for (index, targetSourceURL) in targetSourceURLs.enumerated() {
            let sanitizedSource = try sanitizedSourceFile(
                at: targetSourceURL,
                currentDiscovery: discovery
            )
            generatedSources.append(
                GeneratedSource(
                    fileName: "TargetSources/\(index)-\(targetSourceURL.lastPathComponent)",
                    content: sanitizedSource
                )
            )
        }

        generatedSources.append(
            GeneratedSource(
                fileName: "PreviewEntry.swift",
                content: try viewEntrySource(
                    for: discovery,
                    configuration: configuration
                )
            )
        )
        return generatedSources
    }

    private func write(_ sources: [GeneratedSource], to directory: URL) throws -> [URL] {
        try sources.map { source in
            let sourceURL = directory.appendingPathComponent(source.fileName, isDirectory: false)
            try FileManager.default.createDirectory(
                at: sourceURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try source.content.write(to: sourceURL, atomically: true, encoding: .utf8)
            return sourceURL
        }
    }

    private func viewEntrySource(
        for discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration
    ) throws -> String {
        let descriptorSource = try descriptorFunctionSource(for: discovery, configuration: configuration)
        let bodySource = discovery.bodySource?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let viewBody = (bodySource?.isEmpty == false) ? bodySource! : #"Text("Empty Preview")"#

        return """
        import AppKit
        import Darwin
        import SwiftUI

        \(descriptorSource)

        @_cdecl("\(Self.viewSymbolName)")
        public func lumiPreviewMakeNSView() -> UnsafeMutableRawPointer? {
            let rootView = AnyView({
        \(Self.indented(viewBody, spaces: 8))
            }())
            let view = NSHostingView(rootView: rootView)
            view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
            return Unmanaged.passRetained(view).toOpaque()
        }
        """
    }

    private func descriptorEntrySource(
        for discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration,
        viewEntryBuildError: String? = nil
    ) throws -> String {
        let descriptorSource = try descriptorFunctionSource(
            for: discovery,
            configuration: configuration,
            viewEntryBuildError: viewEntryBuildError
        )

        return """
        import Darwin

        \(descriptorSource)
        """
    }

    private func descriptorFunctionSource(
        for discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration,
        viewEntryBuildError: String? = nil
    ) throws -> String {
        let descriptor = PreviewEntryDescriptor(
            title: discovery.title,
            subtitle: discovery.primaryTypeName,
            body: descriptorBody(
                for: discovery,
                configuration: configuration
            ),
            diagnostics: viewEntryBuildError.map { Self.truncated($0, limit: 4_000) },
            isFallback: viewEntryBuildError != nil
        )
        let data = try encoder.encode(descriptor)
        let json = String(data: data, encoding: .utf8) ?? "{}"

        return """
        @_cdecl("\(Self.symbolName)")
        public func lumiPreviewEntry() -> UnsafePointer<CChar>? {
            let json = "\(Self.swiftStringLiteralContents(json))"
            return strdup(json).map { UnsafePointer($0) }
        }
        """
    }

    private func descriptorBody(
        for discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration
    ) -> String? {
        var parts: [String] = []

        if let bodySource = discovery.bodySource?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !bodySource.isEmpty {
            parts.append(bodySource)
        }

        if configuration.hasEnvironmentInjections {
            parts.append("\(configuration.environmentInjections.count) environment mock(s)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    private func sourceFiles(for discovery: PreviewDiscovery, buildStrategy: BuildStrategy?) -> [URL] {
        let currentSourceURL = discovery.sourceFileURL.standardizedFileURL.resolvingSymlinksInPath()
        var sourceURLs: [URL]

        if case .spm(let packageDirectory, let targetName) = buildStrategy {
            sourceURLs = BuildPlanner.swiftSourceFiles(packageDirectory: packageDirectory, targetName: targetName)
        } else if case .xcode(let projectURL, let scheme, _) = buildStrategy {
            sourceURLs = BuildPlanner.swiftSourceFiles(
                projectURL: projectURL,
                scheme: scheme,
                containing: currentSourceURL
            )
        } else {
            sourceURLs = []
        }

        if !sourceURLs.contains(currentSourceURL) {
            sourceURLs.append(currentSourceURL)
        }

        return sourceURLs
            .map { $0.standardizedFileURL.resolvingSymlinksInPath() }
            .uniqued()
            .filter { $0 == currentSourceURL || $0.lastPathComponent != "main.swift" }
            .sorted { $0.path < $1.path }
    }

    private func sanitizedSourceFile(
        at sourceFileURL: URL,
        currentDiscovery: PreviewDiscovery
    ) throws -> String {
        let normalizedSourceURL = sourceFileURL.standardizedFileURL.resolvingSymlinksInPath()
        let currentSourceURL = currentDiscovery.sourceFileURL.standardizedFileURL.resolvingSymlinksInPath()
        let source: String
        if normalizedSourceURL == currentSourceURL,
           let sourceText = currentDiscovery.sourceText {
            source = sourceText
        } else {
            source = try String(contentsOf: sourceFileURL, encoding: .utf8)
        }
        let previews = PreviewScanner().scan(
            fileURL: sourceFileURL,
            sourceText: source
        )
        var lines = source.components(separatedBy: .newlines)
        for preview in previews.sorted(by: { $0.lineNumber > $1.lineNumber }) {
            let start = max(preview.lineNumber - 1, 0)
            let end = min(preview.endLineNumber - 1, lines.count - 1)
            guard start <= end else { continue }
            lines.replaceSubrange(start...end, with: [])
        }

        removeMainAttribute(from: &lines)
        return lines.joined(separator: "\n")
    }

    private func removeMainAttribute(from lines: inout [String]) {
        for index in lines.indices.reversed() {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "@main" {
                lines.remove(at: index)
            } else if trimmed.hasPrefix("@main "),
                      let range = lines[index].range(of: "@main") {
                lines[index].removeSubrange(range)
            }
        }
    }

    private static func indented(_ value: String, spaces: Int) -> String {
        let padding = String(repeating: " ", count: spaces)
        return value
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "\(padding)\($0)" }
            .joined(separator: "\n")
    }

    private static func swiftStringLiteralContents(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func diagnosticMessage(from error: Error) -> String {
        if case PreviewError.compilationFailed(let message) = error {
            return message
        }

        return String(describing: error)
    }

    private static func truncated(_ value: String, limit: Int) -> String {
        guard value.count > limit else {
            return value
        }

        return "\(value.prefix(limit))..."
    }
}

private extension Array where Element == URL {
    func uniqued() -> [URL] {
        var seen: Set<String> = []
        var result: [URL] = []
        for url in self {
            if seen.insert(url.path).inserted {
                result.append(url)
            }
        }
        return result
    }
}
