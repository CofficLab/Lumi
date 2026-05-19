import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("XcodeCompiler")
struct XcodeCompilerTests {

    @Test("编译 .xcodeproj → 成功返回产物路径")
    func buildXcodeProjectReturnsProduct() async throws {
        let project = try makeTemporaryXcodeProject(
            targetName: "TinyTool",
            source: """
            print("hello")
            """
        )
        defer { try? FileManager.default.removeItem(at: project.rootDirectory) }

        let productURL = try await LumiPreviewFacade.XcodeCompiler().build(
            projectURL: project.projectURL,
            scheme: "TinyTool",
            configuration: "Debug"
        )

        #expect(FileManager.default.fileExists(atPath: productURL.path))
        #expect(productURL.lastPathComponent == "TinyTool")
    }

    @Test("编译 .xcodeproj 时使用自定义 DerivedData")
    func buildXcodeProjectUsesCustomDerivedDataPath() async throws {
        let project = try makeTemporaryXcodeProject(
            targetName: "TinyTool",
            source: """
            print("hello")
            """
        )
        let derivedDataURL = project.rootDirectory
            .appendingPathComponent("CustomDerivedData", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: project.rootDirectory) }

        let productURL = try await LumiPreviewFacade.XcodeCompiler(
            derivedDataPath: derivedDataURL
        ).build(
            projectURL: project.projectURL,
            scheme: "TinyTool",
            configuration: "Debug"
        )

        #expect(FileManager.default.fileExists(atPath: productURL.path))
        #expect(productURL.path.hasPrefix(derivedDataURL.path))
        #expect(FileManager.default.fileExists(
            atPath: derivedDataURL
                .appendingPathComponent("Build/Intermediates.noindex/XCBuildData/build.db")
                .path
        ))
    }

    @Test("编译不存在的 Xcode 项目 → 抛出 compilationFailed")
    func buildMissingProjectThrowsCompilationFailed() async throws {
        let missingProjectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Missing-\(UUID().uuidString).xcodeproj", isDirectory: true)

        do {
            _ = try await LumiPreviewFacade.XcodeCompiler().build(
                projectURL: missingProjectURL,
                scheme: "Missing",
                configuration: "Debug"
            )
            Issue.record("Expected compilationFailed")
        } catch LumiPreviewFacade.PreviewError.compilationFailed(let message) {
            let includesUsefulDiagnostic = message.localizedCaseInsensitiveContains("xcodebuild")
                || message.localizedCaseInsensitiveContains("error")
                || message.localizedCaseInsensitiveContains("does not exist")
            #expect(includesUsefulDiagnostic)
        } catch {
            Issue.record("Expected compilationFailed, got \(error)")
        }
    }

    @Test("从 build log 提取 swift-frontend 编译命令")
    func extractCompileCommandFromBuildLog() {
        let fileURL = URL(fileURLWithPath: "/tmp/SampleView.swift")
        let expectedCommand = """
        /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-frontend -frontend -c /tmp/SampleView.swift -module-name App
        """
        let buildLog = """
        SwiftCompile normal arm64 Other.swift
        \(expectedCommand)
        """

        let command = LumiPreviewFacade.XcodeCompiler().extractCompileCommand(for: fileURL, buildLog: buildLog)

        #expect(command == expectedCommand)
    }

    @Test("preview compiler arguments include Xcode deployment target")
    func previewCompilerArgumentsIncludeDeploymentTarget() async throws {
        let project = try makeTemporaryXcodeProject(
            targetName: "TinyTool",
            source: """
            print("hello")
            """
        )
        defer { try? FileManager.default.removeItem(at: project.rootDirectory) }

        let arguments = try await LumiPreviewFacade.XcodeCompiler().previewCompilerArguments(
            projectURL: project.projectURL,
            scheme: "TinyTool",
            configuration: "Debug"
        )

        guard let targetIndex = arguments.firstIndex(of: "-target"),
              arguments.indices.contains(arguments.index(after: targetIndex)) else {
            Issue.record("Expected preview compiler arguments to include -target, got \(arguments)")
            return
        }

        #expect(arguments[arguments.index(after: targetIndex)].contains("-apple-macos14.0"))
    }

    private func makeTemporaryXcodeProject(
        targetName: String,
        source: String
    ) throws -> (rootDirectory: URL, projectURL: URL) {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-LumiPreviewFacade.XcodeCompiler-\(UUID().uuidString)", isDirectory: true)
        let projectURL = rootDirectory.appendingPathComponent("\(targetName).xcodeproj", isDirectory: true)
        let sourceDirectory = rootDirectory.appendingPathComponent("Sources", isDirectory: true)

        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try source.write(
            to: sourceDirectory.appendingPathComponent("main.swift"),
            atomically: true,
            encoding: .utf8
        )
        try projectFileContent(targetName: targetName).write(
            to: projectURL.appendingPathComponent("project.pbxproj"),
            atomically: true,
            encoding: .utf8
        )

        return (rootDirectory, projectURL)
    }

    private func projectFileContent(targetName: String) -> String {
        """
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
        \t\t\t\t000000000000000000000003,
        \t\t\t);
        \t\t\tsourceTree = "<group>";
        \t\t};
        \t\t000000000000000000000003 = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (000000000000000000000006);
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
        \t\t\texplicitFileType = compiled.mach-o.executable;
        \t\t\tincludeInIndex = 0;
        \t\t\tpath = \(targetName);
        \t\t\tsourceTree = BUILT_PRODUCTS_DIR;
        \t\t};
        \t\t000000000000000000000007 = {
        \t\t\tisa = PBXBuildFile;
        \t\t\tfileRef = 000000000000000000000005;
        \t\t};
        \t\t000000000000000000000008 = {
        \t\t\tisa = PBXSourcesBuildPhase;
        \t\t\tbuildActionMask = 2147483647;
        \t\t\tfiles = (000000000000000000000007);
        \t\t\trunOnlyForDeploymentPostprocessing = 0;
        \t\t};
        \t\t000000000000000000000004 = {
        \t\t\tisa = PBXNativeTarget;
        \t\t\tbuildConfigurationList = 000000000000000000000020;
        \t\t\tbuildPhases = (000000000000000000000008);
        \t\t\tbuildRules = ();
        \t\t\tdependencies = ();
        \t\t\tname = \(targetName);
        \t\t\tproductName = \(targetName);
        \t\t\tproductReference = 000000000000000000000006;
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
}
