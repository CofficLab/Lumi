import CryptoKit
import Foundation

public extension LumiPreviewFacade {
/// Builds a small dynamic preview entry dylib for a discovered `#Preview`.
final class PreviewEntryBuilder: Sendable {
    /// The C symbol exported by generated preview entry dylibs.
    public static let symbolName = "lumi_preview_entry"

    /// The C symbol dynamic preview dylibs can export to return a retained `NSView`.
    public static let viewSymbolName = "lumi_preview_make_nsview"

    /// Swift condition flags for preview entry dylibs, matching Xcode Debug `#Preview` builds.
    public static let previewDebugConditionArguments: [String] = ["-DDEBUG"]

    private let incrementalCompiler: IncrementalCompiler
    private let spmCompiler: SPMCompiler
    private let xcodeCompiler: XcodeCompiler
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

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

    /// Removes stale generated preview entry cache directories.
    ///
    /// The host process may keep dylibs mapped while a session is alive, so cleanup only
    /// removes old entries and leaves recent cache hits intact.
    public static func removeExpiredCacheEntries(
        olderThan age: TimeInterval = 7 * 24 * 60 * 60,
        keepingNewest maximumEntryCount: Int = 64,
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil,
        now: Date = Date()
    ) {
        let root = rootDirectory ?? cacheRootDirectory
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let cacheEntries = entries.compactMap { url -> (url: URL, modifiedAt: Date)? in
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
            guard values?.isDirectory == true else {
                try? fileManager.removeItem(at: url)
                return nil
            }
            return (url, values?.contentModificationDate ?? .distantPast)
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }

        for (index, entry) in cacheEntries.enumerated() {
            let isExpired = now.timeIntervalSince(entry.modifiedAt) > age
            let exceedsCount = index >= maximumEntryCount
            if isExpired || exceedsCount {
                try? fileManager.removeItem(at: entry.url)
            }
        }
    }

    /// Generates, compiles, links, and signs a preview entry dylib.
    ///
    /// When target context is available, the generated entry is compiled with
    /// sanitized target sources so `#Preview` bodies can reference sibling files.
    ///
    /// - Parameter forceSourceInclude: When `true`, always collects and inlines target
    ///   source files instead of attempting module import. This is necessary for targets
    ///   like Xcode app targets that don't export internal symbols via their swiftmodule.
    public func buildEntry(
        for discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration,
        buildStrategy: BuildStrategy? = nil,
        forceSourceInclude: Bool = false
    ) async throws -> URL {
        let generatedSources = try viewEntrySources(
            for: discovery,
            configuration: configuration,
            buildStrategy: buildStrategy,
            forceSourceInclude: forceSourceInclude
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
    }

    private static func cacheDirectory(for fingerprint: String) -> URL {
        cacheRootDirectory
            .appendingPathComponent(fingerprint, isDirectory: true)
    }

    private static var cacheRootDirectory: URL {
        PreviewStorage.paths.previewEntryCacheDirectory
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

    private static func configurationFingerprint(_ configuration: PreviewRenderConfiguration) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(configuration),
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
        var arguments: [String]
        switch buildStrategy {
        case .spm(let packageDirectory, let targetName):
            arguments = spmCompiler.previewCompilerArguments(
                packageDirectory: packageDirectory,
                targetName: targetName
            )
        case .xcode(let projectURL, let scheme, let configuration):
            arguments = try await xcodeCompiler.previewCompilerArguments(
                projectURL: projectURL,
                scheme: scheme,
                configuration: configuration
            )
        case .incremental, .none:
            arguments = []
        }
        arguments.append(contentsOf: Self.previewDebugConditionArguments)
        return arguments
    }

    private struct GeneratedSource {
        let fileName: String
        let content: String
    }

    private func viewEntrySources(
        for discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration,
        buildStrategy: BuildStrategy?,
        forceSourceInclude: Bool = false
    ) throws -> [GeneratedSource] {
        let targetSourceURLs = sourceFiles(
            for: discovery,
            buildStrategy: buildStrategy,
            forceSourceInclude: forceSourceInclude
        )
        let moduleNameToRemove = selfImportModuleName(for: buildStrategy)
        var generatedSources: [GeneratedSource] = []
        for (index, targetSourceURL) in targetSourceURLs.enumerated() {
            let sanitizedSource = try sanitizedSourceFile(
                at: targetSourceURL,
                currentDiscovery: discovery,
                removingSelfImportModuleName: moduleNameToRemove
            )
            generatedSources.append(
                GeneratedSource(
                    fileName: "TargetSources/\(index)-\(targetSourceURL.lastPathComponent)",
                    content: sanitizedSource
                )
            )
        }

        let inlinesTargetSources = !targetSourceURLs.isEmpty
        generatedSources.append(
            GeneratedSource(
                fileName: "PreviewEntry.swift",
                content: try viewEntrySource(
                    for: discovery,
                    configuration: configuration,
                    buildStrategy: buildStrategy,
                    forceSourceInclude: forceSourceInclude || inlinesTargetSources
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
        configuration: PreviewRenderConfiguration,
        buildStrategy: BuildStrategy?,
        forceSourceInclude: Bool = false
    ) throws -> String {
        let descriptorSource = try descriptorFunctionSource(for: discovery, configuration: configuration)
        let bodySource = discovery.bodySource?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let viewBody = (bodySource?.isEmpty == false) ? bodySource! : #"Text("Empty Preview")"#
        let rootViewSource = Self.rootViewSource(for: viewBody, layout: discovery.layout)
        // When force-including source files, don't import the module —
        // all types are available via inlined source files.
        let importLine: String
        if forceSourceInclude {
            importLine = ""
        } else {
            importLine = importModuleName(for: buildStrategy).map { "import \($0)\n" } ?? ""
        }

        return """
        import AppKit
        import Darwin
        import SwiftUI
        \(importLine)
        \(descriptorSource)

        @_cdecl("\(Self.viewSymbolName)")
        public func lumiPreviewMakeNSView() -> UnsafeMutableRawPointer? {
            let rootView = \(rootViewSource)
            let view = NSHostingView(rootView: rootView)
            view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
            return Unmanaged.passRetained(view).toOpaque()
        }
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

    private func sourceFiles(
        for discovery: PreviewDiscovery,
        buildStrategy: BuildStrategy?,
        forceSourceInclude: Bool = false
    ) -> [URL] {
        let currentSourceURL = discovery.sourceFileURL.standardizedFileURL.resolvingSymlinksInPath()

        if !forceSourceInclude,
           !isSPMBuildStrategy(buildStrategy),
           buildStrategy != nil,
           LumiPreviewFacade.ModuleImportEligibilityChecker().shouldUseModuleImport(discovery: discovery) {
            return []
        }

        var sourceURLs: [URL]

        if case .spm(let packageDirectory, let targetName) = buildStrategy {
            sourceURLs = spmTargetSourceFiles(
                packageDirectory: packageDirectory,
                targetName: targetName,
                currentSourceURL: currentSourceURL
            )
        } else if case .xcode(let projectURL, let scheme, _) = buildStrategy {
            sourceURLs = BuildPlanner.swiftSourceFiles(
                projectURL: projectURL,
                scheme: scheme,
                containing: currentSourceURL
            )
        } else {
            sourceURLs = [currentSourceURL]
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

    private func isSPMBuildStrategy(_ buildStrategy: BuildStrategy?) -> Bool {
        if case .spm = buildStrategy {
            return true
        }
        return false
    }

    private func spmTargetSourceFiles(
        packageDirectory: URL,
        targetName: String,
        currentSourceURL: URL
    ) -> [URL] {
        let targetDirectory = packageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(targetName, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: targetDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return [currentSourceURL]
        }

        var sourceURLs: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile != false {
                sourceURLs.append(url)
            }
        }
        if sourceURLs.isEmpty {
            sourceURLs.append(currentSourceURL)
        }
        return sourceURLs
    }

    private func linksPrebuiltModuleArtifacts(for buildStrategy: BuildStrategy) -> Bool {
        switch buildStrategy {
        case .spm(let packageDirectory, let targetName):
            let arguments = spmCompiler.previewCompilerArguments(
                packageDirectory: packageDirectory,
                targetName: targetName
            )
            return arguments.contains { $0.hasSuffix(".o") }
        case .xcode:
            return true
        case .incremental:
            return false
        }
    }

    private func importModuleName(for buildStrategy: BuildStrategy?) -> String? {
        guard let buildStrategy else { return nil }
        switch buildStrategy {
        case .spm(_, let targetName):
            return targetName
        case .xcode(_, let scheme, _):
            return scheme
        case .incremental:
            return nil
        }
    }

    private func sanitizedSourceFile(
        at sourceFileURL: URL,
        currentDiscovery: PreviewDiscovery,
        removingSelfImportModuleName moduleName: String?
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
        if let moduleName {
            removeSelfImports(of: moduleName, from: &lines)
        }
        Self.replaceBundleModuleReferences(in: &lines)
        return lines.joined(separator: "\n")
    }

    private func selfImportModuleName(for buildStrategy: BuildStrategy?) -> String? {
        guard case .spm(_, let targetName) = buildStrategy else {
            return nil
        }
        return targetName
    }

    private func removeSelfImports(of moduleName: String, from lines: inout [String]) {
        guard !moduleName.isEmpty else { return }
        let escapedModuleName = NSRegularExpression.escapedPattern(for: moduleName)
        let pattern = #"^\s*(?:(?:@testable|@_exported)\s+)?import\s+\#(escapedModuleName)\s*(?://.*)?$"#

        for index in lines.indices.reversed() {
            if lines[index].range(of: pattern, options: .regularExpression) != nil {
                lines.remove(at: index)
            }
        }
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

    /// Replaces `Bundle.module` with `Bundle.main` so preview entry dylibs compile
    /// outside the original SPM target context.
    ///
    /// SwiftPM auto-generates a `resource_bundle_accessor.swift` that declares
    /// `Bundle.module` as `internal`.  Preview entry dylibs are compiled in an
    /// isolated context without that accessor, so any `Bundle.module` reference
    /// produces "'module' is inaccessible due to 'internal' protection level".
    private static func replaceBundleModuleReferences(in lines: inout [String]) {
        for index in lines.indices {
            if lines[index].contains("Bundle.module") {
                lines[index] = lines[index].replacingOccurrences(
                    of: "Bundle.module",
                    with: "Bundle.main"
                )
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

    private static func rootViewSource(
        for body: String,
        layout: PreviewDiscovery.Layout
    ) -> String {
        let expression: String
        switch layout {
        case .automatic, .sizeThatFits:
            expression = "{\n\(indented(body, spaces: 8))\n}()"
        case let .fixed(width, height):
            expression = "{\n\(indented(body, spaces: 8))\n}()\n.frame(width: \(literal(width)), height: \(literal(height)))"
        }
        return "AnyView(\(expression))"
    }

    private static func literal(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
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
