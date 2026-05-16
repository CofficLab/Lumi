import Foundation
import Darwin
import LumiPreviewKit
import Testing
@testable import LumiPreviewKit

actor InvocationCounter {
    private var count = 0

    func increment() {
        count += 1
    }

    func value() -> Int {
        count
    }
}

@Suite("IncrementalBuildPipeline")
struct IncrementalBuildPipelineTests {
    @Test("extracts xcode and swift build frontend commands for requested files")
    func extractsFrontendCommands() throws {
        let pipeline = LumiPreviewFacade.IncrementalBuildPipeline()
        let firstFileURL = URL(fileURLWithPath: "/tmp/First.swift")
        let secondFileURL = URL(fileURLWithPath: "/tmp/Second.swift")
        let buildLog = [
            "/usr/bin/swift-frontend -c /tmp/First.swift -o /tmp/First.o",
            "CompileSwift normal arm64 /tmp/ignore.swift",
            "/Applications/Xcode.app/usr/bin/swift-frontend -c /tmp/Second.swift -o /tmp/Second.o"
        ].joined(separator: "\n")

        let commands = pipeline.extractCommands(
            from: buildLog,
            fileURLs: [firstFileURL, secondFileURL]
        )

        #expect(commands[firstFileURL]?.contains("/tmp/First.swift") == true)
        #expect(commands[secondFileURL]?.contains("/tmp/Second.swift") == true)
    }

    @Test("ignores files that do not appear in the build log")
    func ignoresMissingFiles() {
        let pipeline = LumiPreviewFacade.IncrementalBuildPipeline()
        let fileURL = URL(fileURLWithPath: "/tmp/Missing.swift")
        let commands = pipeline.extractCommands(
            from: "/usr/bin/swift-frontend -c /tmp/Other.swift -o /tmp/Other.o",
            fileURLs: [fileURL]
        )

        #expect(commands.isEmpty)
    }

    @Test("resolves unique module search paths from compiler arguments")
    func resolvesModuleSearchPaths() async throws {
        let pipeline = LumiPreviewFacade.IncrementalBuildPipeline(
            compilerArgumentResolver: { _ in
                [
                    "-I", "/tmp/Build/Debug",
                    "-F", "/tmp/Build/Debug",
                    "-I/tmp/Build/Modules",
                    "-I", "/tmp/Build/Debug"
                ]
            }
        )

        let paths = try await pipeline.resolveModuleSearchPaths(
            buildStrategy: .spm(
                packageDirectory: URL(fileURLWithPath: "/tmp/Demo"),
                targetName: "DemoModule"
            )
        )

        #expect(paths == ["/tmp/Build/Debug", "/tmp/Build/Modules"])
    }

    @Test("generates import-based preview entry source")
    func generatesImportBasedEntrySource() async throws {
        let pipeline = LumiPreviewFacade.IncrementalBuildPipeline(
            compilerArgumentResolver: { _ in
                ["-module-name", "DemoModule", "-I", "/tmp/Build/Debug"]
            }
        )
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview.demo",
            title: "Demo",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Demo.swift"),
            lineNumber: 10,
            endLineNumber: 14,
            bodySource: "DemoView()"
        )

        let source = try await pipeline.generateEntryImportingModule(
            discovery: discovery,
            buildStrategy: .xcode(
                projectURL: URL(fileURLWithPath: "/tmp/Demo.xcodeproj"),
                scheme: "DemoApp",
                configuration: "Debug"
            )
        )

        #expect(source.contains(LumiPreviewFacade.PreviewEntryBuilder.symbolName))
        #expect(source.contains("import DemoModule"))
        #expect(source.contains("let rootView = AnyView({ DemoView() }())"))
        #expect(source.contains(LumiPreviewFacade.PreviewEntryBuilder.viewSymbolName))
        #expect(source.contains("\\\"title\\\":\\\"Demo\\\""))
    }

    @Test("prefers resolved xcode module name over scheme name")
    func prefersResolvedXcodeModuleName() async throws {
        let pipeline = LumiPreviewFacade.IncrementalBuildPipeline(
            compilerArgumentResolver: { _ in
                ["-I", "/tmp/Build/Debug"]
            },
            moduleNameResolver: { strategy in
                guard case .xcode = strategy else { return nil }
                return "ActualModule"
            }
        )
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview.actual-module",
            title: "Demo",
            sourceFileURL: URL(fileURLWithPath: "/tmp/Demo.swift"),
            lineNumber: 10,
            endLineNumber: 14,
            bodySource: "DemoView()"
        )

        let source = try await pipeline.generateEntryImportingModule(
            discovery: discovery,
            buildStrategy: .xcode(
                projectURL: URL(fileURLWithPath: "/tmp/Demo.xcodeproj"),
                scheme: "AppScheme",
                configuration: "Debug"
            )
        )

        #expect(source.contains("import ActualModule"))
        #expect(!source.contains("import AppScheme"))
    }

    @Test("caches resolved module import plans by build strategy")
    func cachesResolvedModuleImportPlansByBuildStrategy() async throws {
        let argumentCounter = InvocationCounter()
        let moduleCounter = InvocationCounter()
        let pipeline = LumiPreviewFacade.IncrementalBuildPipeline(
            compilerArgumentResolver: { _ in
                await argumentCounter.increment()
                return ["-I", "/tmp/Build/Debug"]
            },
            moduleNameResolver: { strategy in
                await moduleCounter.increment()
                guard case .xcode = strategy else { return nil }
                return "ActualModule"
            }
        )
        let strategy = LumiPreviewFacade.BuildStrategy.xcode(
            projectURL: URL(fileURLWithPath: "/tmp/Demo.xcodeproj"),
            scheme: "AppScheme",
            configuration: "Debug"
        )

        let first = try await pipeline.resolveModuleImportPlan(buildStrategy: strategy)
        let second = try await pipeline.resolveModuleImportPlan(buildStrategy: strategy)

        #expect(first == second)
        #expect(await argumentCounter.value() == 1)
        #expect(await moduleCounter.value() == 1)
    }

    @Test("marks module import plan usable when module artifact exists")
    func marksModuleImportPlanUsableWhenModuleArtifactExists() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let modulesDirectory = directory.appendingPathComponent("Modules", isDirectory: true)
        try FileManager.default.createDirectory(at: modulesDirectory, withIntermediateDirectories: true)
        let artifactURL = modulesDirectory.appendingPathComponent("ActualModule.swiftmodule")
        try Data().write(to: artifactURL)

        let pipeline = LumiPreviewFacade.IncrementalBuildPipeline(
            compilerArgumentResolver: { _ in
                ["-I", directory.path]
            },
            moduleNameResolver: { _ in
                "ActualModule"
            }
        )

        let plan = try await pipeline.resolveModuleImportPlan(
            buildStrategy: .xcode(
                projectURL: URL(fileURLWithPath: "/tmp/Demo.xcodeproj"),
                scheme: "AppScheme",
                configuration: "Debug"
            )
        )

        #expect(plan.hasUsableModuleArtifact)
        #expect(plan.moduleArtifactPath == artifactURL.path)
    }

    @Test("marks module import plan unusable when module artifact is missing")
    func marksModuleImportPlanUnusableWhenModuleArtifactIsMissing() async throws {
        let pipeline = LumiPreviewFacade.IncrementalBuildPipeline(
            compilerArgumentResolver: { _ in
                ["-I", "/tmp/DoesNotExist"]
            },
            moduleNameResolver: { _ in
                "MissingModule"
            }
        )

        let plan = try await pipeline.resolveModuleImportPlan(
            buildStrategy: .spm(
                packageDirectory: URL(fileURLWithPath: "/tmp/Demo"),
                targetName: "MissingModule"
            )
        )

        #expect(!plan.hasUsableModuleArtifact)
        #expect(plan.moduleArtifactPath == nil)
    }

    @Test("emits interposable linker flags for preview entry dylibs")
    func emitsInterposableLinkerFlagsForPreviewEntryDylibs() {
        let command = LumiPreviewFacade.IncrementalBuildPipeline.emitLibraryCommand(
            inputPaths: ["/tmp/PreviewEntry.o"],
            dylibOutputPath: "/tmp/PreviewEntry.dylib",
            additionalArguments: ["-module-name", "DemoPreview"],
            enableInterposableLinking: true,
            enableDeadStripLinking: true
        )

        #expect(command.contains("-Xlinker"))
        #expect(command.contains("-interposable"))
        #expect(command.contains("-dead_strip"))
        #expect(command.contains("DemoPreview"))
        #expect(command.contains("/tmp/PreviewEntry.dylib"))
    }

    @Test("generates source-include entry source without target-wide source inclusion")
    func generatesSourceIncludeEntrySource() throws {
        let pipeline = LumiPreviewFacade.IncrementalBuildPipeline()
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview.source-include",
            title: "SourceInclude",
            sourceFileURL: URL(fileURLWithPath: "/tmp/SourceInclude.swift"),
            lineNumber: 10,
            endLineNumber: 14,
            bodySource: "DemoView()"
        )

        let source = try pipeline.generateEntryIncludingCurrentSource(
            discovery: discovery,
            configuration: .empty
        )

        #expect(source.contains(LumiPreviewFacade.PreviewEntryBuilder.symbolName))
        #expect(source.contains(LumiPreviewFacade.PreviewEntryBuilder.viewSymbolName))
        #expect(source.contains("let rootView = AnyView({"))
        #expect(source.contains("DemoView()"))
    }

    @Test("current source sanitization strips preview blocks and main attribute")
    func currentSourceSanitizationStripsPreviewBlocksAndMainAttribute() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        let existingGeneratedDirectories = Set(
            (try? fileManager.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ))?.filter { $0.lastPathComponent.hasPrefix("LumiPreviewKit-SourceEntry-") }
            .map(\.path) ?? []
        )
        let sourceURL = directory.appendingPathComponent("Demo.swift")
        try """
        import SwiftUI

        @main
        struct DemoApp: App {
            var body: some Scene { WindowGroup { DemoView() } }
        }

        struct DemoView: View {
            var body: some View { Text("Demo") }
        }

        #Preview {
            DemoView()
        }
        """.write(to: sourceURL, atomically: true, encoding: .utf8)

        let pipeline = LumiPreviewFacade.IncrementalBuildPipeline(
            compilerArgumentResolver: { _ in [] }
        )
        let discovery = LumiPreviewFacade.PreviewDiscovery(
            id: "preview.sanitized",
            title: "Sanitized",
            sourceFileURL: sourceURL,
            lineNumber: 11,
            endLineNumber: 13,
            bodySource: "DemoView()",
            sourceText: try String(contentsOf: sourceURL, encoding: .utf8)
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
        #expect(!sanitizedSource.contains("#Preview"))
        #expect(!sanitizedSource.contains("@main"))
        #expect(sanitizedSource.contains("struct DemoView"))
    }

    @Test("SPM package preview with internal type and same-target helpers produces real NSView entry")
    func packagePreviewWithInternalTypeAndSameTargetHelpersProducesRealNSViewEntry() async throws {
        let packageDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: packageDirectory) }

        try """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "InternalPreviewFixture",
            platforms: [.macOS(.v14)],
            products: [
                .library(name: "InternalPreviewFixture", targets: ["InternalPreviewFixture"])
            ],
            targets: [
                .target(name: "InternalPreviewFixture")
            ]
        )
        """.write(
            to: packageDirectory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let sourceDirectory = packageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("InternalPreviewFixture", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)

        let previewSourceURL = sourceDirectory.appendingPathComponent("PreviewSource.swift")
        try """
        import SwiftUI

        struct InternalPreviewView: View {
            var body: some View {
                Text("Preview")
                    .fixturePadding()
            }
        }

        #Preview("Internal Package Preview") {
            InternalPreviewView()
        }
        """.write(to: previewSourceURL, atomically: true, encoding: .utf8)

        try """
        import SwiftUI

        public extension View {
            func fixturePadding() -> some View {
                padding(8)
            }
        }
        """.write(
            to: sourceDirectory.appendingPathComponent("View+FixturePadding.swift"),
            atomically: true,
            encoding: .utf8
        )

        try """
        import SwiftUI
        import InternalPreviewFixture

        struct SameTargetSelfImportUse: View {
            var body: some View {
                Text("Self import")
                    .fixturePadding()
            }
        }
        """.write(
            to: sourceDirectory.appendingPathComponent("SameTargetSelfImportUse.swift"),
            atomically: true,
            encoding: .utf8
        )

        try runSwiftBuild(packageDirectory: packageDirectory, targetName: "InternalPreviewFixture")

        let sourceText = try String(contentsOf: previewSourceURL, encoding: .utf8)
        let discovery = try #require(
            LumiPreviewFacade.PreviewScanner()
                .scan(fileURL: previewSourceURL, sourceText: sourceText)
                .first
        )

        let entryURL = try await LumiPreviewFacade.PreviewEntryBuilder().buildEntry(
            for: discovery,
            configuration: .empty,
            buildStrategy: .spm(
                packageDirectory: packageDirectory,
                targetName: "InternalPreviewFixture"
            )
        )

        guard let handle = dlopen(entryURL.path, RTLD_NOW | RTLD_LOCAL) else {
            let message = dlerror().map { String(cString: $0) } ?? "unknown dlopen error"
            Issue.record("Failed to open preview entry dylib: \(message)")
            return
        }
        defer { dlclose(handle) }

        #expect(dlsym(handle, LumiPreviewFacade.PreviewEntryBuilder.viewSymbolName) != nil)
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
