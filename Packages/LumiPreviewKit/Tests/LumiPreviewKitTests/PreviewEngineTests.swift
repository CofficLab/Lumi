import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("LivePreviewEngine")
struct PreviewEngineTests {

    @Test("完整的 scan → build → launch → render → refresh → stop 管线")
    func fullPreviewPipeline() async throws {
        let package = try makeTemporaryPackage(
            targetName: "PreviewTarget",
            source: """
            import SwiftUI

            struct TestPreviewView: View {
                var body: some View {
                    Text("Hello")
                }
            }

            #Preview("Test Preview") {
                TestPreviewView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LivePreviewEngine(hostExecutableURL: hostExecutableURL)

        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
        #expect(discoveries.count == 1)
        #expect(discoveries[0].title == "Test Preview")

        let session = try await engine.startPreview(discoveries[0])
        #expect(await session.state == .running)
        let startResponse = await session.lastRenderResponse
        #expect(startResponse?.message == "Loaded preview view entry Test Preview")
        #expect(startResponse?.previewImagePNGBase64 != nil)
        let startMetrics = await session.performanceMetrics
        #expect(startMetrics.lastCompileDuration != nil)
        #expect(startMetrics.lastCompileUsedCache == false)

        try await engine.refreshPreview(session)
        #expect(await session.state == .running)
        let refreshResponse = await session.lastRenderResponse
        #expect(refreshResponse?.message == "Loaded preview view entry Test Preview")
        #expect(refreshResponse?.previewImagePNGBase64 != nil)
        let refreshMetrics = await session.performanceMetrics
        #expect(refreshMetrics.lastCompileDuration != nil)
        #expect(refreshMetrics.lastRefreshDuration != nil)
        #expect(refreshMetrics.lastCompileUsedCache == true)

        await engine.stopPreview(session)
        #expect(await session.state == .stopped)
    }

    @Test("SPM target 跨文件 #Preview → 生成真实 NSView entry")
    func spmCrossFilePreviewUsesTargetSources() async throws {
        let package = try makeTemporaryPackage(
            targetName: "CrossFilePreviewTarget",
            source: """
            import SwiftUI

            #Preview("Cross File") {
                CrossFilePreviewView()
            }
            """,
            extraSources: [
                "CrossFilePreviewView.swift": """
                import SwiftUI

                struct CrossFilePreviewView: View {
                    var body: some View {
                        Text("Cross File")
                    }
                }
                """
            ]
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LivePreviewEngine(hostExecutableURL: hostExecutableURL)

        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
        #expect(discoveries.count == 1)
        #expect(discoveries[0].title == "Cross File")

        let session = try await engine.startPreview(discoveries[0])
        #expect(await session.state == .running)
        #expect(await session.lastRenderResponse?.message == "Loaded preview view entry Cross File")
        #expect(await session.lastRenderResponse?.previewImagePNGBase64 != nil)

        await engine.stopPreview(session)
    }

    @Test("编译失败 → session 状态变为 failed")
    func compileFailureMarksSessionFailed() async throws {
        let package = try makeTemporaryPackage(
            targetName: "BrokenPreviewTarget",
            source: """
            import SwiftUI

            struct BrokenPreviewView: View {
                var body: some View {
                    Text("Hello")
                }
            }

            #Preview("Broken") {
                BrokenPreviewView()
            }

            let broken =
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let engine = LivePreviewEngine(
            hostExecutableURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("missing-host-\(UUID().uuidString)")
        )
        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
        #expect(discoveries.count == 1)

        let session = try await engine.startPreview(discoveries[0])
        guard case .failed(.compilationFailed(let message)) = await session.state else {
            Issue.record("Expected compilationFailed, got \(await session.state)")
            return
        }
        #expect(message.contains("TestView.swift"))
    }

    @Test("宿主进程崩溃后 refresh 自动重启")
    func refreshRestartsCrashedHost() async throws {
        let package = try makeTemporaryPackage(
            targetName: "RestartPreviewTarget",
            source: """
            import SwiftUI

            struct RestartPreviewView: View {
                var body: some View {
                    Text("Restart")
                }
            }

            #Preview("Restart") {
                RestartPreviewView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
        #expect(discoveries.count == 1)

        let session = try await engine.startPreview(discoveries[0])
        #expect(await session.state == .running)

        guard let liveSession = session as? LivePreviewSession else {
            Issue.record("Expected LivePreviewSession")
            return
        }
        await liveSession.terminateHost()

        try await engine.refreshPreview(session)
        #expect(await session.state == .running)
        #expect(await session.performanceMetrics.lastRefreshDuration != nil)
        #expect(await session.lastRenderResponse?.message == "Loaded preview view entry Restart")

        await engine.stopPreview(session)
    }

    @Test("环境注入配置随预览会话启动、刷新和宿主重启保留")
    func environmentInjectionConfigurationSurvivesRefreshAndHostRestart() async throws {
        let package = try makeTemporaryPackage(
            targetName: "EnvironmentPreviewTarget",
            source: """
            import SwiftUI

            final class MockAppModel: ObservableObject {}

            struct EnvironmentPreviewView: View {
                @EnvironmentObject var model: MockAppModel

                var body: some View {
                    Text("Environment")
                }
            }

            #Preview("Environment") {
                EnvironmentPreviewView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
        #expect(discoveries.count == 1)

        let configuration = PreviewRenderConfiguration(
            environmentInjections: [
                PreviewEnvironmentInjection(
                    typeName: "MockAppModel",
                    mockIdentifier: "preview.mockAppModel",
                    displayName: "Preview Mock App Model"
                )
            ]
        )
        let session = try await engine.startPreview(discoveries[0], configuration: configuration)
        #expect(await session.state == .running)
        #expect(await session.configuration == configuration)
        #expect(await session.lastRenderResponse?.message == "Loaded preview view entry Environment")

        let updatedConfiguration = PreviewRenderConfiguration(
            environmentInjections: [
                PreviewEnvironmentInjection(
                    typeName: "MockAppModel",
                    mockIdentifier: "preview.updatedMockAppModel",
                    displayName: "Updated Mock App Model"
                )
            ]
        )
        try await engine.refreshPreview(session, configuration: updatedConfiguration)
        #expect(await session.state == .running)
        #expect(await session.configuration == updatedConfiguration)

        guard let liveSession = session as? LivePreviewSession else {
            Issue.record("Expected LivePreviewSession")
            return
        }
        await liveSession.terminateHost()

        try await engine.refreshPreview(session)
        #expect(await session.state == .running)
        #expect(await session.configuration == updatedConfiguration)

        await engine.stopPreview(session)
    }

    @Test("并发启动多个预览 → 共享构建并分别运行")
    func startsMultiplePreviewsConcurrently() async throws {
        let package = try makeTemporaryPackage(
            targetName: "ConcurrentPreviewTarget",
            source: """
            import SwiftUI

            struct FirstConcurrentPreviewView: View {
                var body: some View {
                    Text("First")
                }
            }

            struct SecondConcurrentPreviewView: View {
                var body: some View {
                    Text("Second")
                }
            }

            #Preview("First") {
                FirstConcurrentPreviewView()
            }

            #Preview("Second") {
                SecondConcurrentPreviewView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: package.directory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        let discoveries = await engine.discoverPreviews(in: package.sourceFile)
            .sorted { $0.title < $1.title }
        #expect(discoveries.map(\.title) == ["First", "Second"])

        async let firstSession = engine.startPreview(discoveries[0])
        async let secondSession = engine.startPreview(discoveries[1])
        let sessions = try await [firstSession, secondSession]

        #expect(await sessions[0].state == .running)
        #expect(await sessions[1].state == .running)

        let metrics = await [
            sessions[0].performanceMetrics,
            sessions[1].performanceMetrics
        ]
        #expect(metrics.allSatisfy { $0.lastCompileDuration != nil })
        #expect(metrics.contains { $0.lastCompileUsedCache })

        await engine.stopPreview(sessions[0])
        await engine.stopPreview(sessions[1])
        #expect(await sessions[0].state == .stopped)
        #expect(await sessions[1].state == .stopped)
    }

    @Test("Xcode 项目 scan → build → launch → render → stop 管线")
    func fullXcodePreviewPipeline() async throws {
        let project = try makeTemporaryXcodeProject(
            targetName: "XcodePreviewTool",
            previewSource: """
            import SwiftUI

            struct XcodePreviewView: View {
                var body: some View {
                    Text("Xcode Preview")
                }
            }

            #Preview("Xcode Preview") {
                XcodePreviewView()
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: project.rootDirectory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LivePreviewEngine(hostExecutableURL: hostExecutableURL)

        let discoveries = await engine.discoverPreviews(in: project.previewFile)
        #expect(discoveries.count == 1)
        #expect(discoveries[0].title == "Xcode Preview")

        let session = try await engine.startPreview(discoveries[0])
        #expect(await session.state == .running)
        #expect(await session.lastRenderResponse?.message == "Loaded preview view entry Xcode Preview")
        #expect(await session.lastRenderResponse?.previewImagePNGBase64 != nil)
        let metrics = await session.performanceMetrics
        #expect(metrics.lastCompileDuration != nil)
        #expect(metrics.lastCompileUsedCache == false)

        await engine.stopPreview(session)
        #expect(await session.state == .stopped)
    }

    @Test("Xcode 项目跨文件 #Preview → 生成真实 NSView entry")
    func xcodeCrossFilePreviewUsesTargetSources() async throws {
        let project = try makeTemporaryXcodeProject(
            targetName: "XcodeCrossFilePreviewTool",
            previewSource: """
            import SwiftUI

            #Preview("Xcode Cross File") {
                XcodeCrossFilePreviewView()
            }
            """,
            extraSources: [
                "XcodeCrossFilePreviewView.swift": """
                import SwiftUI

                struct XcodeCrossFilePreviewView: View {
                    var body: some View {
                        Text("Xcode Cross File")
                    }
                }
                """
            ]
        )
        defer { try? FileManager.default.removeItem(at: project.rootDirectory) }

        let hostExecutableURL = try buildHostExecutable()
        let engine = LivePreviewEngine(hostExecutableURL: hostExecutableURL)

        let discoveries = await engine.discoverPreviews(in: project.previewFile)
        #expect(discoveries.count == 1)
        #expect(discoveries[0].title == "Xcode Cross File")

        let session = try await engine.startPreview(discoveries[0])
        #expect(await session.state == .running)
        #expect(await session.lastRenderResponse?.message == "Loaded preview view entry Xcode Cross File")
        #expect(await session.lastRenderResponse?.previewImagePNGBase64 != nil)

        await engine.stopPreview(session)
    }

    @Test("真实 view entry 构建失败 → 返回结构化诊断")
    func previewViewEntryFailureReturnsStructuredDiagnostics() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewEntryDiagnostics-\(UUID().uuidString)", isDirectory: true)
        let sourceFile = directory.appendingPathComponent("main.swift")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try """
            import SwiftUI

            print("top-level executable entry")

            #Preview("Broken Entry") {
                Text("Fallback")
            }
            """.write(to: sourceFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: directory) }

        let hostExecutableURL = try buildHostExecutable()
        let connection = try await PreviewHostProcess().launch(executableURL: hostExecutableURL)
        defer {
            Task {
                await connection.terminate()
            }
        }

        let source = try String(contentsOf: sourceFile, encoding: .utf8)
        let discoveries = PreviewScanner().scan(fileURL: sourceFile, sourceText: source)
        #expect(discoveries.count == 1)

        let entryURL = try await PreviewEntryBuilder().buildEntry(
            for: discoveries[0],
            configuration: .empty,
            buildStrategy: .incremental(fileURL: sourceFile, compileCommand: "")
        )
        let response = try await connection.requestLoadPreviewEntry(
            at: entryURL,
            symbolName: PreviewEntryBuilder.symbolName
        )

        #expect(response.message == "Loaded preview entry Broken Entry")
        #expect(response.isFallback == true)
        #expect(response.diagnostics?.contains("expressions are not allowed at the top level") == true)
        #expect(response.previewImagePNGBase64 != nil)
        await connection.terminate()
    }

    private func makeTemporaryPackage(
        targetName: String,
        source: String,
        extraSources: [String: String] = [:]
    ) throws -> (directory: URL, sourceFile: URL) {
        let packageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewEngineTests-\(UUID().uuidString)", isDirectory: true)
        let sourceDirectory = packageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(targetName, isDirectory: true)
        let sourceFile = sourceDirectory.appendingPathComponent("TestView.swift")

        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "\(targetName)Package",
            platforms: [.macOS(.v14)],
            targets: [
                .target(name: "\(targetName)")
            ]
        )
        """.write(
            to: packageDirectory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )
        try source.write(to: sourceFile, atomically: true, encoding: .utf8)
        for (fileName, content) in extraSources {
            let extraSourceFile = sourceDirectory.appendingPathComponent(fileName)
            try FileManager.default.createDirectory(
                at: extraSourceFile.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try content.write(to: extraSourceFile, atomically: true, encoding: .utf8)
        }

        return (packageDirectory, sourceFile)
    }

    private func makeTemporaryXcodeProject(
        targetName: String,
        previewSource: String,
        extraSources: [String: String] = [:]
    ) throws -> (rootDirectory: URL, previewFile: URL) {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewEngine-Xcode-\(UUID().uuidString)", isDirectory: true)
        let projectURL = rootDirectory.appendingPathComponent("\(targetName).xcodeproj", isDirectory: true)
        let sourceDirectory = rootDirectory.appendingPathComponent("Sources", isDirectory: true)
        let mainFile = sourceDirectory.appendingPathComponent("main.swift")
        let previewFile = sourceDirectory.appendingPathComponent("PreviewView.swift")

        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try "print(\"preview host build target\")\n".write(to: mainFile, atomically: true, encoding: .utf8)
        try previewSource.write(to: previewFile, atomically: true, encoding: .utf8)
        for (fileName, content) in extraSources {
            let extraSourceFile = sourceDirectory.appendingPathComponent(fileName)
            try FileManager.default.createDirectory(
                at: extraSourceFile.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try content.write(to: extraSourceFile, atomically: true, encoding: .utf8)
        }

        try xcodeProjectContent(
            targetName: targetName,
            extraSwiftFiles: extraSources.keys.sorted()
        ).write(
            to: projectURL.appendingPathComponent("project.pbxproj"),
            atomically: true,
            encoding: .utf8
        )

        return (rootDirectory, previewFile)
    }

    private func xcodeProjectContent(targetName: String, extraSwiftFiles: [String]) -> String {
        let extraFileReferences = extraSwiftFiles.enumerated().map { index, fileName in
            """
            \t\t\(pbxID(0x100 + index)) = {
            \t\t\tisa = PBXFileReference;
            \t\t\tlastKnownFileType = sourcecode.swift;
            \t\t\tpath = Sources/\(fileName);
            \t\t\tsourceTree = "<group>";
            \t\t};
            """
        }.joined(separator: "\n")
        let extraGroupChildren = extraSwiftFiles.enumerated().map { index, _ in
            "\t\t\t\t\(pbxID(0x100 + index)),"
        }.joined(separator: "\n")
        let extraBuildFiles = extraSwiftFiles.enumerated().map { index, _ in
            """
            \t\t\(pbxID(0x200 + index)) = {
            \t\t\tisa = PBXBuildFile;
            \t\t\tfileRef = \(pbxID(0x100 + index));
            \t\t};
            """
        }.joined(separator: "\n")
        let extraSourceFiles = extraSwiftFiles.enumerated().map { index, _ in
            "\t\t\t\t\(pbxID(0x200 + index)),"
        }.joined(separator: "\n")

        return """
        // !$*UTF8*$!
        {
        \tarchiveVersion = 1;
        \tclasses = {};
        \tobjectVersion = 56;
        \tobjects = {
        \t\t000000000000000000000001 = {
        \t\t\tisa = PBXProject;
        \t\t\tattributes = {
        \t\t\t\tLastSwiftUpdateCheck = 1500;
        \t\t\t\tLastUpgradeCheck = 1500;
        \t\t\t};
        \t\t\tbuildConfigurationList = 000000000000000000000010;
        \t\t\tcompatibilityVersion = "Xcode 14.0";
        \t\t\tdevelopmentRegion = en;
        \t\t\thasScannedForEncodings = 0;
        \t\t\tknownRegions = (en, Base);
        \t\t\tmainGroup = 000000000000000000000002;
        \t\t\tproductRefGroup = 000000000000000000000003;
        \t\t\tprojectDirPath = "";
        \t\t\tprojectRoot = "";
        \t\t\ttargets = (000000000000000000000004);
        \t\t};
        \t\t000000000000000000000002 = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (
        \t\t\t\t000000000000000000000005,
        \t\t\t\t000000000000000000000006,
        \(extraGroupChildren)
        \t\t\t\t000000000000000000000003,
        \t\t\t);
        \t\t\tsourceTree = "<group>";
        \t\t};
        \t\t000000000000000000000003 = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (000000000000000000000007);
        \t\t\tname = Products;
        \t\t\tsourceTree = "<group>";
        \t\t};
        \t\t000000000000000000000005 = {
        \t\t\tisa = PBXFileReference;
        \t\t\tlastKnownFileType = sourcecode.swift;
        \t\t\tpath = Sources/main.swift;
        \t\t\tsourceTree = "<group>";
        \t\t};
        \t\t000000000000000000000006 = {
        \t\t\tisa = PBXFileReference;
        \t\t\tlastKnownFileType = sourcecode.swift;
        \t\t\tpath = Sources/PreviewView.swift;
        \t\t\tsourceTree = "<group>";
        \t\t};
        \(extraFileReferences)
        \t\t000000000000000000000007 = {
        \t\t\tisa = PBXFileReference;
        \t\t\texplicitFileType = compiled.mach-o.executable;
        \t\t\tincludeInIndex = 0;
        \t\t\tpath = \(targetName);
        \t\t\tsourceTree = BUILT_PRODUCTS_DIR;
        \t\t};
        \t\t000000000000000000000008 = {
        \t\t\tisa = PBXBuildFile;
        \t\t\tfileRef = 000000000000000000000005;
        \t\t};
        \t\t000000000000000000000009 = {
        \t\t\tisa = PBXBuildFile;
        \t\t\tfileRef = 000000000000000000000006;
        \t\t};
        \(extraBuildFiles)
        \t\t00000000000000000000000A = {
        \t\t\tisa = PBXSourcesBuildPhase;
        \t\t\tbuildActionMask = 2147483647;
        \t\t\tfiles = (
        \t\t\t\t000000000000000000000008,
        \t\t\t\t000000000000000000000009,
        \(extraSourceFiles)
        \t\t\t);
        \t\t\trunOnlyForDeploymentPostprocessing = 0;
        \t\t};
        \t\t000000000000000000000004 = {
        \t\t\tisa = PBXNativeTarget;
        \t\t\tbuildConfigurationList = 000000000000000000000020;
        \t\t\tbuildPhases = (00000000000000000000000A);
        \t\t\tbuildRules = ();
        \t\t\tdependencies = ();
        \t\t\tname = \(targetName);
        \t\t\tproductName = \(targetName);
        \t\t\tproductReference = 000000000000000000000007;
        \t\t\tproductType = "com.apple.product-type.tool";
        \t\t};
        \t\t000000000000000000000010 = {
        \t\t\tisa = XCConfigurationList;
        \t\t\tbuildConfigurations = (
        \t\t\t\t000000000000000000000011,
        \t\t\t\t000000000000000000000012,
        \t\t\t);
        \t\t\tdefaultConfigurationIsVisible = 0;
        \t\t\tdefaultConfigurationName = Debug;
        \t\t};
        \t\t000000000000000000000011 = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tSDKROOT = macosx;
        \t\t\t};
        \t\t\tname = Debug;
        \t\t};
        \t\t000000000000000000000012 = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tSDKROOT = macosx;
        \t\t\t};
        \t\t\tname = Release;
        \t\t};
        \t\t000000000000000000000020 = {
        \t\t\tisa = XCConfigurationList;
        \t\t\tbuildConfigurations = (
        \t\t\t\t000000000000000000000021,
        \t\t\t\t000000000000000000000022,
        \t\t\t);
        \t\t\tdefaultConfigurationIsVisible = 0;
        \t\t\tdefaultConfigurationName = Debug;
        \t\t};
        \t\t000000000000000000000021 = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tCODE_SIGNING_ALLOWED = NO;
        \t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
        \t\t\t\tPRODUCT_NAME = \(targetName);
        \t\t\t\tSWIFT_VERSION = 6.0;
        \t\t\t};
        \t\t\tname = Debug;
        \t\t};
        \t\t000000000000000000000022 = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tCODE_SIGNING_ALLOWED = NO;
        \t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
        \t\t\t\tPRODUCT_NAME = \(targetName);
        \t\t\t\tSWIFT_VERSION = 6.0;
        \t\t\t};
        \t\t\tname = Release;
        \t\t};
        \t};
        \trootObject = 000000000000000000000001;
        }
        """
    }

    private func pbxID(_ value: Int) -> String {
        String(format: "%024X", value)
    }

    private func buildHostExecutable() throws -> URL {
        let packageDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scratchPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewEngineHost-build-\(UUID().uuidString)", isDirectory: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "swift",
            "build",
            "--package-path",
            packageDirectory.path,
            "--scratch-path",
            scratchPath.path,
            "--product",
            "LumiPreviewHostApp"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw PreviewError.compilationFailed(message: output)
        }

        guard let executableURL = findHostExecutable(in: scratchPath) else {
            throw PreviewError.buildProductNotFound
        }

        return executableURL
    }

    private func findHostExecutable(in scratchPath: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: scratchPath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator where url.lastPathComponent == "LumiPreviewHostApp" {
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        return nil
    }
}
