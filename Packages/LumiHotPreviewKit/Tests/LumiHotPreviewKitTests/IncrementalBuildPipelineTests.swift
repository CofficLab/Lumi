import Foundation
import LumiPreviewKit
import Testing
@testable import LumiHotPreviewKit

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
        let pipeline = LumiHotPreviewPackage.IncrementalBuildPipeline()
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
        let pipeline = LumiHotPreviewPackage.IncrementalBuildPipeline()
        let fileURL = URL(fileURLWithPath: "/tmp/Missing.swift")
        let commands = pipeline.extractCommands(
            from: "/usr/bin/swift-frontend -c /tmp/Other.swift -o /tmp/Other.o",
            fileURLs: [fileURL]
        )

        #expect(commands.isEmpty)
    }

    @Test("resolves unique module search paths from compiler arguments")
    func resolvesModuleSearchPaths() async throws {
        let pipeline = LumiHotPreviewPackage.IncrementalBuildPipeline(
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
        let pipeline = LumiHotPreviewPackage.IncrementalBuildPipeline(
            compilerArgumentResolver: { _ in
                ["-module-name", "DemoModule", "-I", "/tmp/Build/Debug"]
            }
        )
        let discovery = LumiPreviewPackage.PreviewDiscovery(
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

        #expect(source.contains(LumiPreviewPackage.PreviewEntryBuilder.symbolName))
        #expect(source.contains("import DemoModule"))
        #expect(source.contains("let rootView = AnyView({ DemoView() }())"))
        #expect(source.contains(LumiPreviewPackage.PreviewEntryBuilder.viewSymbolName))
        #expect(source.contains("\\\"title\\\":\\\"Demo\\\""))
    }

    @Test("prefers resolved xcode module name over scheme name")
    func prefersResolvedXcodeModuleName() async throws {
        let pipeline = LumiHotPreviewPackage.IncrementalBuildPipeline(
            compilerArgumentResolver: { _ in
                ["-I", "/tmp/Build/Debug"]
            },
            moduleNameResolver: { strategy in
                guard case .xcode = strategy else { return nil }
                return "ActualModule"
            }
        )
        let discovery = LumiPreviewPackage.PreviewDiscovery(
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
        let pipeline = LumiHotPreviewPackage.IncrementalBuildPipeline(
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
        let strategy = LumiPreviewPackage.BuildStrategy.xcode(
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

        let pipeline = LumiHotPreviewPackage.IncrementalBuildPipeline(
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
        let pipeline = LumiHotPreviewPackage.IncrementalBuildPipeline(
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
        let command = LumiHotPreviewPackage.IncrementalBuildPipeline.emitLibraryCommand(
            inputPaths: ["/tmp/PreviewEntry.o"],
            dylibOutputPath: "/tmp/PreviewEntry.dylib",
            additionalArguments: ["-module-name", "DemoPreview"],
            enableInterposableLinking: true
        )

        #expect(command.contains("-Xlinker"))
        #expect(command.contains("-interposable"))
        #expect(command.contains("DemoPreview"))
        #expect(command.contains("/tmp/PreviewEntry.dylib"))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiHotPreviewKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
