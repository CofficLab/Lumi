import Foundation
import LumiPreviewKit
import Testing
@testable import LumiPreviewKit

@Suite("Bundle.module Sanitization")
struct BundleModuleSanitizationTests {
    /// Verifies that source files using `Bundle.module` are sanitized so the
    /// generated preview entry can compile without the auto-generated
    /// `resource_bundle_accessor.swift`.
    ///
    /// When an SPM target declares resources, SwiftPM generates an internal
    /// `Bundle.module` accessor. Preview entry dylibs are compiled outside the
    /// original target context, so any reference to `Bundle.module` causes:
    ///
    ///     error: 'module' is inaccessible due to 'internal' protection level
    ///
    /// The sanitization step must replace `Bundle.module` with a safe fallback
    /// (e.g. `Bundle.main`) so the live preview compiles successfully.
    @Test("source-include entry replaces Bundle.module with Bundle.main in sanitized current source")
    func sourceIncludeEntryReplacesBundleModuleWithBundleMain() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory

        // Track existing generated directories so we can find the new one.
        let existingGeneratedDirectories = Set(
            (try? fileManager.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ))?.filter { $0.lastPathComponent.hasPrefix("LumiPreviewKit-SourceEntry-") }
                .map(\.path) ?? []
        )

        let sourceURL = directory.appendingPathComponent("BundleModuleDemo.swift")
        let sourceText = """
        import SwiftUI

        struct BundleModuleDemoView: View {
            let apps = ["Facetime", "Message", "Mail"]

            var body: some View {
                HStack(spacing: 8) {
                    ForEach(apps, id: \\.self) { app in
                        Image(app, bundle: Bundle.module)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                    }
                }
            }
        }

        #Preview("Bundle Module Demo") {
            BundleModuleDemoView()
        }
        """
        try sourceText.write(to: sourceURL, atomically: true, encoding: .utf8)

        let pipeline = LumiPreviewFacade.IncrementalBuildPipeline(
            compilerArgumentResolver: { _ in [] }
        )
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview.bundle-module",
            title: "Bundle Module Demo",
            sourceFileURL: sourceURL,
            lineNumber: 17,
            endLineNumber: 19,
            bodySource: "BundleModuleDemoView()",
            sourceText: sourceText
        )

        _ = try await pipeline.compilePreviewEntryIncludingCurrentSource(
            discovery: discovery,
            configuration: .empty,
            buildStrategy: .incremental(fileURL: sourceURL, compileCommand: "/usr/bin/env swiftc")
        )

        let generatedDirectories = try fileManager.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter {
            $0.lastPathComponent.hasPrefix("LumiPreviewKit-SourceEntry-")
                && !existingGeneratedDirectories.contains($0.path)
        }
        #expect(generatedDirectories.count == 1)
        guard let latestDirectory = generatedDirectories.first else {
            Issue.record("Expected generated source entry directory")
            return
        }

        let sanitizedSource = try String(
            contentsOf: latestDirectory.appendingPathComponent("CurrentSource.swift"),
            encoding: .utf8
        )

        // The sanitized source must NOT contain Bundle.module
        #expect(
            !sanitizedSource.contains("Bundle.module"),
            "Sanitized source still contains 'Bundle.module' — this will cause 'module' is inaccessible due to 'internal' protection level compilation errors in preview entry dylibs. Expected replacement with Bundle.main."
        )

        // The sanitized source SHOULD contain Bundle.main as a safe fallback
        #expect(
            sanitizedSource.contains("Bundle.main"),
            "Sanitized source should replace Bundle.module with Bundle.main so preview entries compile outside the original SPM target context."
        )

        // Non-Bundle.module code should remain intact
        #expect(sanitizedSource.contains("struct BundleModuleDemoView"))
        #expect(sanitizedSource.contains("Image(app, bundle:"))
    }

    /// Verifies that SPM package preview entry (target-wide source inclusion)
    /// also sanitizes `Bundle.module` references when compiling the preview entry dylib.
    ///
    /// This mirrors the real-world scenario where a dependency like MagicKit uses
    /// `Bundle.module` for image resources, and the preview entry builder includes
    /// those sources when building the preview dylib.
    @Test("SPM package entry replaces Bundle.module in target-wide source inclusion")
    func spmPackageEntryReplacesBundleModuleInTargetWideSourceInclusion() async throws {
        let packageDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: packageDirectory) }

        // Create a minimal SPM package with resources
        try """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "BundleModuleFixture",
            platforms: [.macOS(.v14)],
            products: [
                .library(name: "BundleModuleFixture", targets: ["BundleModuleFixture"])
            ],
            targets: [
                .target(
                    name: "BundleModuleFixture",
                    resources: [.process("Assets.xcassets")]
                )
            ]
        )
        """.write(
            to: packageDirectory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let sourceDirectory = packageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("BundleModuleFixture", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)

        // Create a minimal Assets.xcassets to satisfy SPM resource declaration
        let assetsDirectory = sourceDirectory.appendingPathComponent("Assets.xcassets", isDirectory: true)
        try FileManager.default.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)
        try """
        {
          "info" : {
            "author" : "xcode",
            "version" : 1
          }
        }
        """.write(
            to: assetsDirectory.appendingPathComponent("Contents.json"),
            atomically: true,
            encoding: .utf8
        )

        // Source file that uses Bundle.module — same pattern as MagicKit's MacDesktop.swift
        let previewSourceURL = sourceDirectory.appendingPathComponent("BundleModuleView.swift")
        try """
        import SwiftUI

        struct BundleModuleView: View {
            let iconNames = ["Star", "Heart", "Bell"]

            var body: some View {
                HStack(spacing: 8) {
                    ForEach(iconNames, id: \\.self) { name in
                        Image(name, bundle: Bundle.module)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                    }
                }
            }
        }

        #Preview("Bundle Module Package Preview") {
            BundleModuleView()
        }
        """.write(to: previewSourceURL, atomically: true, encoding: .utf8)

        // Build the SPM target so compiler arguments are available
        try runSwiftBuild(packageDirectory: packageDirectory, targetName: "BundleModuleFixture")

        let sourceText = try String(contentsOf: previewSourceURL, encoding: .utf8)
        let discovery = try #require(
            LumiPreviewFacade.PreviewScanner()
                .scan(fileURL: previewSourceURL, sourceText: sourceText)
                .first
        )

        // This should succeed (not fall back to descriptor-only entry) when
        // Bundle.module references are properly sanitized.
        let entryURL = try await LumiPreviewFacade.PreviewEntryBuilder().buildEntry(
            for: discovery,
            configuration: .empty,
            buildStrategy: .spm(
                packageDirectory: packageDirectory,
                targetName: "BundleModuleFixture"
            )
        )

        // The entry should have a real NSView symbol (live preview), not just a descriptor
        guard let handle = dlopen(entryURL.path, RTLD_NOW | RTLD_LOCAL) else {
            let message = dlerror().map { String(cString: $0) } ?? "unknown dlopen error"
            Issue.record("Failed to open preview entry dylib: \(message)")
            return
        }
        defer { dlclose(handle) }

        #expect(
            dlsym(handle, LumiPreviewFacade.PreviewEntryBuilder.viewSymbolName) != nil,
            "Expected real NSView entry (live preview) but only found descriptor. This means Bundle.module references caused compilation failure and the builder fell back to a descriptor-only entry."
        )
    }

    private func runSwiftBuild(packageDirectory: URL, targetName: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "build", "--target", targetName]
        process.currentDirectoryURL = packageDirectory

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(
                data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            Issue.record("swift build failed: \(output)")
            return
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
