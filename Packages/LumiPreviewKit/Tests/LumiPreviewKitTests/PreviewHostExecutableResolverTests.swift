import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("PreviewHostExecutableResolver")
struct PreviewHostExecutableResolverTests {
    @Test("环境变量中的可执行文件优先")
    func environmentOverrideTakesPrecedence() throws {
        let bundle = try makeBundle()
        let helpersHost = bundle.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("LumiPreviewHostApp")
        let overrideHost = try makeExecutable(name: "OverrideHost")
        defer {
            try? FileManager.default.removeItem(at: bundle.bundleURL)
            try? FileManager.default.removeItem(at: overrideHost.deletingLastPathComponent())
        }
        try makeExecutable(at: helpersHost)

        let resolved = LumiPreviewPackage.PreviewHostExecutableResolver.resolve(
            environment: [LumiPreviewPackage.PreviewHostExecutableResolver.environmentOverrideKey: overrideHost.path],
            bundle: bundle
        )

        #expect(resolved == overrideHost)
    }

    @Test("空环境变量回退到 bundle 候选")
    func emptyEnvironmentOverrideFallsBackToBundleCandidate() throws {
        let bundle = try makeBundle()
        defer { try? FileManager.default.removeItem(at: bundle.bundleURL) }
        let host = bundle.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("LumiPreviewHostApp")
        try makeExecutable(at: host)

        let resolved = LumiPreviewPackage.PreviewHostExecutableResolver.resolve(
            environment: [LumiPreviewPackage.PreviewHostExecutableResolver.environmentOverrideKey: ""],
            bundle: bundle
        )

        #expect(resolved == host)
    }

    @Test("bundle 候选按 Helpers、MacOS、Resources 顺序选择")
    func bundleCandidatesUseExpectedPriority() throws {
        let bundle = try makeBundle()
        defer { try? FileManager.default.removeItem(at: bundle.bundleURL) }
        let helpersHost = bundle.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("LumiPreviewHostApp")
        let macOSHost = bundle.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("LumiPreviewHostApp")
        let resourcesHost = try #require(bundle.resourceURL)
            .appendingPathComponent("LumiPreviewHostApp")

        try makeExecutable(at: resourcesHost)
        try makeExecutable(at: macOSHost)
        #expect(LumiPreviewPackage.PreviewHostExecutableResolver.resolve(environment: [:], bundle: bundle) == macOSHost)

        try makeExecutable(at: helpersHost)
        #expect(LumiPreviewPackage.PreviewHostExecutableResolver.resolve(environment: [:], bundle: bundle) == helpersHost)
    }

    @Test("不可执行文件不会被选中")
    func nonExecutableCandidatesAreIgnored() throws {
        let bundle = try makeBundle()
        defer { try? FileManager.default.removeItem(at: bundle.bundleURL) }
        let host = bundle.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent("LumiPreviewHostApp")
        try FileManager.default.createDirectory(at: host.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: host.path, contents: Data())

        let resolved = LumiPreviewPackage.PreviewHostExecutableResolver.resolve(
            environment: [LumiPreviewPackage.PreviewHostExecutableResolver.environmentOverrideKey: host.path],
            bundle: bundle
        )

        #expect(resolved == nil)
    }

    @Test("candidates 返回预期 bundle 路径")
    func candidatesReturnsExpectedBundlePaths() throws {
        let bundle = try makeBundle()
        defer { try? FileManager.default.removeItem(at: bundle.bundleURL) }

        let candidates = LumiPreviewPackage.PreviewHostExecutableResolver.candidates(in: bundle)

        #expect(candidates.count == 3)
        #expect(candidates[0].path.hasSuffix("Contents/Helpers/LumiPreviewHostApp"))
        #expect(candidates[1].path.hasSuffix("Contents/MacOS/LumiPreviewHostApp"))
        #expect(candidates[2].path.hasSuffix("Contents/Resources/LumiPreviewHostApp"))
    }

    private func makeBundle() throws -> Bundle {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewHostResolver-\(UUID().uuidString).app", isDirectory: true)
        let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.coffic.lumi.preview.tests.\(UUID().uuidString)</string>
            <key>CFBundleName</key>
            <string>PreviewResolverTests</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
        </dict>
        </plist>
        """.write(to: contentsURL.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        return try #require(Bundle(url: bundleURL))
    }

    private func makeExecutable(name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewHostResolver-\(UUID().uuidString)", isDirectory: true)
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
