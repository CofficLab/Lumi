import Foundation
import Testing
@testable import LumiHotPreviewKit

@Suite("HotPreviewHostExecutableResolver")
struct HotPreviewHostExecutableResolverTests {
    @Test("environment override takes precedence")
    func environmentOverrideTakesPrecedence() throws {
        let bundle = try makeBundle()
        let bundledHost = bundle.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("LumiHotPreviewHostApp")
        let overrideHost = try makeExecutable(name: "OverrideHotHost")
        defer {
            try? FileManager.default.removeItem(at: bundle.bundleURL)
            try? FileManager.default.removeItem(at: overrideHost.deletingLastPathComponent())
        }
        try makeExecutable(at: bundledHost)

        let resolved = LumiHotPreviewPackage.HotPreviewHostExecutableResolver.resolve(
            environment: [LumiHotPreviewPackage.HotPreviewHostExecutableResolver.environmentOverrideKey: overrideHost.path],
            bundle: bundle
        )

        #expect(resolved == overrideHost)
    }

    @Test("bundle candidates use expected priority")
    func bundleCandidatesUseExpectedPriority() throws {
        let bundle = try makeBundle()
        defer { try? FileManager.default.removeItem(at: bundle.bundleURL) }
        let helpersHost = bundle.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("LumiHotPreviewHostApp")
        let macOSHost = bundle.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("LumiHotPreviewHostApp")
        let resourcesHost = try #require(bundle.resourceURL)
            .appendingPathComponent("LumiHotPreviewHostApp")

        try makeExecutable(at: resourcesHost)
        try makeExecutable(at: macOSHost)
        #expect(LumiHotPreviewPackage.HotPreviewHostExecutableResolver.resolve(environment: [:], bundle: bundle) == macOSHost)

        try makeExecutable(at: helpersHost)
        #expect(LumiHotPreviewPackage.HotPreviewHostExecutableResolver.resolve(environment: [:], bundle: bundle) == helpersHost)
    }

    @Test("non executable override is ignored")
    func nonExecutableOverrideIsIgnored() throws {
        let bundle = try makeBundle()
        defer { try? FileManager.default.removeItem(at: bundle.bundleURL) }
        let fileURL = bundle.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("LumiHotPreviewHostApp")
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())

        let resolved = LumiHotPreviewPackage.HotPreviewHostExecutableResolver.resolve(
            environment: [LumiHotPreviewPackage.HotPreviewHostExecutableResolver.environmentOverrideKey: fileURL.path],
            bundle: bundle
        )

        #expect(resolved == nil)
    }

    private func makeBundle() throws -> Bundle {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiHotPreviewHostResolver-\(UUID().uuidString).app", isDirectory: true)
        let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.coffic.lumi.hot-preview.tests.\(UUID().uuidString)</string>
            <key>CFBundleName</key>
            <string>HotPreviewResolverTests</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
        </dict>
        </plist>
        """.write(to: contentsURL.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        return try #require(Bundle(url: bundleURL))
    }

    private func makeExecutable(name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiHotPreviewHostResolver-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent(name)
        try makeExecutable(at: url)
        return url
    }

    private func makeExecutable(at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: Data("#!/bin/sh\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}
