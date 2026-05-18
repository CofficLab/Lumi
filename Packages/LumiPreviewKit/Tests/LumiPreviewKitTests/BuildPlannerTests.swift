import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("BuildPlanner")
struct BuildPlannerTests {

    // MARK: - 基本检测

    @Test("无项目上下文的文件 → 返回 nil")
    func planUnknownPath() {
        let planner = LumiPreviewFacade.BuildPlanner()
        let result = planner.plan(for: URL(fileURLWithPath: "/tmp/Nonexistent.swift"))
        #expect(result == nil)
    }

    @Test("SPM Package 中的文件 → 返回 .spm 策略")
    func planSPMFile() {
        let planner = LumiPreviewFacade.BuildPlanner()
        // 使用 LumiPreviewKit 自身的源文件来测试
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LumiPreviewKit/Scanner/LumiPreviewFacade.PreviewScanner.swift")
        let result = planner.plan(for: fileURL)

        guard case let .spm(packageDirectory, targetName) = result else {
            Issue.record("Expected .spm strategy, got \(String(describing: result))")
            return
        }
        #expect(targetName == "LumiPreviewKit")
        #expect(packageDirectory.lastPathComponent == "LumiPreviewKit")
    }

    @Test("Lumi 自身的 LumiUI Package 文件能被正确识别")
    func planLumiUIPackage() {
        let planner = LumiPreviewFacade.BuildPlanner()
        // 通过 #filePath 向上推导到 Lumi 根目录，再定位 LumiUI
        let lumiRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // LumiPreviewKitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // LumiPreviewKit
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // Lumi (root)
        let fileURL = lumiRoot
            .appendingPathComponent("Packages/LumiUI/Sources/LumiUI/DesignSystem/ColorTokens.swift")
        let result = planner.plan(for: fileURL)

        guard case let .spm(packageDirectory, targetName) = result else {
            Issue.record("Expected .spm strategy for LumiUI file, got \(String(describing: result))")
            return
        }
        #expect(packageDirectory.lastPathComponent == "LumiUI")
        #expect(targetName == "LumiUI")
    }

    @Test("LumiHotPreviewHostApp 可执行 target 能被正确识别")
    func planHostAppTarget() {
        let planner = LumiPreviewFacade.BuildPlanner()
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LumiHotPreviewHostApp/main.swift")
        let result = planner.plan(for: fileURL)

        guard case let .spm(_, targetName) = result else {
            Issue.record("Expected .spm strategy for HostApp file, got \(String(describing: result))")
            return
        }
        #expect(targetName == "LumiHotPreviewHostApp")
    }

    @Test("Xcode 项目中的文件 → 返回 .xcode 策略")
    func planXcodeProjectFile() throws {
        let project = try makeTemporaryXcodeContainer(
            extensionName: "xcodeproj",
            schemeName: "SharedAppScheme"
        )
        defer { try? FileManager.default.removeItem(at: project.rootDirectory) }

        let result = LumiPreviewFacade.BuildPlanner().plan(for: project.sourceFile)

        guard case let .xcode(projectURL, scheme, configuration) = result else {
            Issue.record("Expected .xcode strategy, got \(String(describing: result))")
            return
        }

        #expect(projectURL.lastPathComponent == "TemporaryApp.xcodeproj")
        #expect(scheme == "SharedAppScheme")
        #expect(configuration == "Debug")
    }

    @Test("同一目录有 workspace 和 project 时优先使用 workspace")
    func planXcodeWorkspaceBeforeProject() throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-XcodePlanner-\(UUID().uuidString)", isDirectory: true)
        let sourceDirectory = rootDirectory.appendingPathComponent("Sources", isDirectory: true)
        let sourceFile = sourceDirectory.appendingPathComponent("ContentView.swift")
        let workspaceURL = rootDirectory.appendingPathComponent("TemporaryApp.xcworkspace", isDirectory: true)
        let projectURL = rootDirectory.appendingPathComponent("TemporaryApp.xcodeproj", isDirectory: true)

        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try "import SwiftUI\n".write(to: sourceFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let result = LumiPreviewFacade.BuildPlanner().plan(for: sourceFile)

        guard case let .xcode(containerURL, scheme, _) = result else {
            Issue.record("Expected .xcode strategy, got \(String(describing: result))")
            return
        }

        #expect(containerURL.pathExtension == "xcworkspace")
        #expect(scheme == "TemporaryApp")
    }

    @Test("Package.swift 优先于上层 Xcode 项目")
    func planPackageBeforeAncestorXcodeProject() throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-MixedPlanner-\(UUID().uuidString)", isDirectory: true)
        let projectURL = rootDirectory.appendingPathComponent("TemporaryApp.xcodeproj", isDirectory: true)
        let packageDirectory = rootDirectory.appendingPathComponent("NestedPackage", isDirectory: true)
        let sourceDirectory = packageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("NestedTarget", isDirectory: true)
        let sourceFile = sourceDirectory.appendingPathComponent("View.swift")

        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "NestedPackage",
            targets: [.target(name: "NestedTarget")]
        )
        """.write(to: packageDirectory.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try "import SwiftUI\n".write(to: sourceFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let result = LumiPreviewFacade.BuildPlanner().plan(for: sourceFile)

        guard case let .spm(packageURL, targetName) = result else {
            Issue.record("Expected .spm strategy, got \(String(describing: result))")
            return
        }

        #expect(packageURL.lastPathComponent == "NestedPackage")
        #expect(targetName == "NestedTarget")
    }

    @Test("SPM target 支持自定义 path 和 sources")
    func spmTargetWithCustomPathAndSources() throws {
        let packageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-CustomSources-\(UUID().uuidString)", isDirectory: true)
        let targetDirectory = packageDirectory.appendingPathComponent("Feature", isDirectory: true)
        let includedDirectory = targetDirectory.appendingPathComponent("PreviewSources", isDirectory: true)
        let ignoredDirectory = targetDirectory.appendingPathComponent("IgnoredSources", isDirectory: true)
        let includedFile = includedDirectory.appendingPathComponent("Included.swift")
        let ignoredFile = ignoredDirectory.appendingPathComponent("Ignored.swift")

        try FileManager.default.createDirectory(at: includedDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ignoredDirectory, withIntermediateDirectories: true)
        try "struct Included {}\n".write(to: includedFile, atomically: true, encoding: .utf8)
        try "struct Ignored {}\n".write(to: ignoredFile, atomically: true, encoding: .utf8)
        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "CustomSources",
            targets: [
                .target(
                    name: "FeatureTarget",
                    path: "Feature",
                    sources: ["PreviewSources"]
                )
            ]
        )
        """.write(to: packageDirectory.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: packageDirectory) }

        let result = LumiPreviewFacade.BuildPlanner().plan(for: includedFile)
        guard case let .spm(_, targetName) = result else {
            Issue.record("Expected .spm strategy, got \(String(describing: result))")
            return
        }

        let sources = LumiPreviewFacade.BuildPlanner.swiftSourceFiles(packageDirectory: packageDirectory, targetName: "FeatureTarget")
        #expect(targetName == "FeatureTarget")
        #expect(sources == [includedFile.standardizedFileURL.resolvingSymlinksInPath()])
        #expect(LumiPreviewFacade.BuildPlanner().plan(for: ignoredFile) == nil)
    }

    @Test("SPM test target 使用 Tests 默认目录")
    func spmTestTargetUsesDefaultTestsDirectory() throws {
        let packageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-TestTarget-\(UUID().uuidString)", isDirectory: true)
        let testDirectory = packageDirectory
            .appendingPathComponent("Tests", isDirectory: true)
            .appendingPathComponent("FeatureTests", isDirectory: true)
        let testFile = testDirectory.appendingPathComponent("FeatureTests.swift")

        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        try "import Testing\n".write(to: testFile, atomically: true, encoding: .utf8)
        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "Feature",
            targets: [
                .testTarget(name: "FeatureTests")
            ]
        )
        """.write(to: packageDirectory.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: packageDirectory) }

        let result = LumiPreviewFacade.BuildPlanner().plan(for: testFile)
        guard case let .spm(_, targetName) = result else {
            Issue.record("Expected .spm strategy, got \(String(describing: result))")
            return
        }

        #expect(targetName == "FeatureTests")
        #expect(LumiPreviewFacade.BuildPlanner.swiftSourceFiles(packageDirectory: packageDirectory, targetName: "FeatureTests") == [
            testFile.standardizedFileURL.resolvingSymlinksInPath()
        ])
    }

    @Test("SPM target 支持绝对 path")
    func spmTargetWithAbsolutePath() throws {
        let packageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-AbsolutePackage-\(UUID().uuidString)", isDirectory: true)
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-AbsoluteSources-\(UUID().uuidString)", isDirectory: true)
        let sourceFile = sourceDirectory.appendingPathComponent("External.swift")

        try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try "struct External {}\n".write(to: sourceFile, atomically: true, encoding: .utf8)
        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "AbsolutePackage",
            targets: [
                .target(name: "ExternalTarget", path: "\(sourceDirectory.path)")
            ]
        )
        """.write(to: packageDirectory.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: packageDirectory)
            try? FileManager.default.removeItem(at: sourceDirectory)
        }

        #expect(LumiPreviewFacade.BuildPlanner.swiftSourceFiles(packageDirectory: packageDirectory, targetName: "ExternalTarget") == [
            sourceFile.standardizedFileURL.resolvingSymlinksInPath()
        ])
    }

    @Test("Xcode synchronized group → 收集文件系统 Swift 源码")
    func xcodeSynchronizedGroupSources() throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-XcodeSyncedSources-\(UUID().uuidString)", isDirectory: true)
        let projectURL = rootDirectory.appendingPathComponent("SyncedApp.xcodeproj", isDirectory: true)
        let appDirectory = rootDirectory.appendingPathComponent("APP", isDirectory: true)
        let nestedDirectory = appDirectory.appendingPathComponent("Nested", isDirectory: true)
        let excludedDirectory = appDirectory.appendingPathComponent("Excluded", isDirectory: true)
        let appFile = appDirectory.appendingPathComponent("AppView.swift")
        let previewFile = nestedDirectory.appendingPathComponent("PreviewView.swift")
        let ignoredFile = excludedDirectory.appendingPathComponent("Ignored.swift")

        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: excludedDirectory, withIntermediateDirectories: true)
        try "struct AppView {}\n".write(to: appFile, atomically: true, encoding: .utf8)
        try "struct PreviewView {}\n".write(to: previewFile, atomically: true, encoding: .utf8)
        try "struct Ignored {}\n".write(to: ignoredFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        try """
        // !$*UTF8*$!
        {
        \tarchiveVersion = 1;
        \tclasses = {};
        \tobjectVersion = 77;
        \tobjects = {
        \t\t000000000000000000000001 = {
        \t\t\tisa = PBXNativeTarget;
        \t\t\tbuildPhases = ();
        \t\t\tfileSystemSynchronizedGroups = (
        \t\t\t\t000000000000000000000002,
        \t\t\t);
        \t\t\tname = SyncedApp;
        \t\t};
        \t\t000000000000000000000002 /* APP */ = {
        \t\t\tisa = PBXFileSystemSynchronizedRootGroup;
        \t\t\texceptions = (
        \t\t\t\t000000000000000000000003,
        \t\t\t);
        \t\t\tpath = APP;
        \t\t\tsourceTree = "<group>";
        \t\t};
        \t\t000000000000000000000003 = {
        \t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;
        \t\t\tmembershipExceptions = (
        \t\t\t\tExcluded,
        \t\t\t);
        \t\t\ttarget = 000000000000000000000001;
        \t\t};
        \t};
        \trootObject = 000000000000000000000001;
        }
        """.write(to: projectURL.appendingPathComponent("project.pbxproj"), atomically: true, encoding: .utf8)

        let sources = LumiPreviewFacade.BuildPlanner.swiftSourceFiles(
            projectURL: projectURL,
            scheme: "SyncedApp",
            containing: previewFile
        )

        #expect(sources.contains(appFile.standardizedFileURL.resolvingSymlinksInPath()))
        #expect(sources.contains(previewFile.standardizedFileURL.resolvingSymlinksInPath()))
        #expect(!sources.contains(ignoredFile.standardizedFileURL.resolvingSymlinksInPath()))
    }

    @Test("Xcode workspace 根据 contents.xcworkspacedata 解析 project 源码")
    func xcodeWorkspaceUsesReferencedProjects() throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-WorkspaceSources-\(UUID().uuidString)", isDirectory: true)
        let workspaceURL = rootDirectory.appendingPathComponent("App.xcworkspace", isDirectory: true)
        let nestedDirectory = rootDirectory.appendingPathComponent("Nested", isDirectory: true)
        let projectURL = nestedDirectory.appendingPathComponent("WorkspaceApp.xcodeproj", isDirectory: true)
        let sourceFile = nestedDirectory.appendingPathComponent("Sources/AppView.swift")
        let siblingFile = sourceFile.deletingLastPathComponent().appendingPathComponent("PreviewSibling.swift")

        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        try writeXcodeProject(
            at: projectURL,
            targetName: "AppTarget",
            sourceFiles: [sourceFile],
            sourceTree: "SOURCE_ROOT"
        )
        try "struct PreviewSibling {}\n".write(to: siblingFile, atomically: true, encoding: .utf8)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <Workspace version = "1.0">
           <FileRef location = "group:Nested/WorkspaceApp.xcodeproj"></FileRef>
        </Workspace>
        """.write(to: workspaceURL.appendingPathComponent("contents.xcworkspacedata"), atomically: true, encoding: .utf8)
        try writeScheme(named: "SharedScheme", targetName: "AppTarget", in: projectURL)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let sources = LumiPreviewFacade.BuildPlanner.swiftSourceFiles(
            projectURL: workspaceURL,
            scheme: "SharedScheme",
            containing: siblingFile
        )

        #expect(sources.contains(sourceFile.standardizedFileURL.resolvingSymlinksInPath()))
        #expect(sources.contains(siblingFile.standardizedFileURL.resolvingSymlinksInPath()))
    }

    @Test("Xcode workspace 缺少 contents 时回退到同级 project")
    func xcodeWorkspaceFallsBackToSiblingProjects() throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-WorkspaceFallback-\(UUID().uuidString)", isDirectory: true)
        let workspaceURL = rootDirectory.appendingPathComponent("App.xcworkspace", isDirectory: true)
        let projectURL = rootDirectory.appendingPathComponent("FallbackApp.xcodeproj", isDirectory: true)
        let sourceFile = rootDirectory.appendingPathComponent("Sources/AppView.swift")

        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try writeXcodeProject(at: projectURL, targetName: "FallbackApp", sourceFiles: [sourceFile])
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let sources = LumiPreviewFacade.BuildPlanner.swiftSourceFiles(
            projectURL: workspaceURL,
            scheme: "FallbackApp",
            containing: sourceFile
        )

        #expect(sources == [sourceFile.standardizedFileURL.resolvingSymlinksInPath()])
    }

    @Test("Xcode scheme 缺失时根据当前文件所属 target 回退")
    func xcodeSourcesFallbackToContainingTarget() throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-ContainingTarget-\(UUID().uuidString)", isDirectory: true)
        let projectURL = rootDirectory.appendingPathComponent("ContainingApp.xcodeproj", isDirectory: true)
        let sourceFile = rootDirectory.appendingPathComponent("Sources/AppView.swift")

        try writeXcodeProject(at: projectURL, targetName: "ActualTarget", sourceFiles: [sourceFile])
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let sources = LumiPreviewFacade.BuildPlanner.swiftSourceFiles(
            projectURL: projectURL,
            scheme: "MissingScheme",
            containing: sourceFile
        )

        #expect(sources == [sourceFile.standardizedFileURL.resolvingSymlinksInPath()])
    }

    private func makeTemporaryXcodeContainer(
        extensionName: String,
        schemeName: String
    ) throws -> (rootDirectory: URL, sourceFile: URL) {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-XcodePlanner-\(UUID().uuidString)", isDirectory: true)
        let sourceDirectory = rootDirectory.appendingPathComponent("Sources", isDirectory: true)
        let sourceFile = sourceDirectory.appendingPathComponent("ContentView.swift")
        let projectURL = rootDirectory.appendingPathComponent("TemporaryApp.\(extensionName)", isDirectory: true)
        let schemesDirectory = projectURL
            .appendingPathComponent("xcshareddata", isDirectory: true)
            .appendingPathComponent("xcschemes", isDirectory: true)

        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: schemesDirectory, withIntermediateDirectories: true)
        try "import SwiftUI\n".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "<Scheme />\n".write(
            to: schemesDirectory.appendingPathComponent("\(schemeName).xcscheme"),
            atomically: true,
            encoding: .utf8
        )

        return (rootDirectory, sourceFile)
    }

    private func writeScheme(named schemeName: String, targetName: String, in projectURL: URL) throws {
        let schemesDirectory = projectURL
            .appendingPathComponent("xcshareddata", isDirectory: true)
            .appendingPathComponent("xcschemes", isDirectory: true)
        try FileManager.default.createDirectory(at: schemesDirectory, withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <Scheme LastUpgradeVersion = "1600" version = "1.7">
           <BuildAction>
              <BuildActionEntries>
                 <BuildActionEntry buildForRunning = "YES">
                    <BuildableReference
                       BlueprintName = "\(targetName)">
                    </BuildableReference>
                 </BuildActionEntry>
              </BuildActionEntries>
           </BuildAction>
        </Scheme>
        """.write(
            to: schemesDirectory.appendingPathComponent("\(schemeName).xcscheme"),
            atomically: true,
            encoding: .utf8
        )
    }

    // MARK: - resources 误匹配 sources 回归测试

    @Test("target 同时声明 resources 时，sources 不会被误匹配为 resources 的内容")
    func spmTargetWithResourcesDoesNotPolluteSources() throws {
        // 复现：MagicKit 的 Package.swift 中 target 声明了 resources: [.process("Icons.xcassets")]
        // parseTargets 的 sourcesPattern（/sources:\s*\[([^\]]*)\]/）错误匹配到 "reSOURCES"
        // 导致 sources 被解析为 ["Icons.xcassets"]，进而使路径匹配失败
        let packageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-ResourcesRegression-\(UUID().uuidString)", isDirectory: true)
        let sourceDirectory = packageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("MagicKit", isDirectory: true)
        let buttonDirectory = sourceDirectory.appendingPathComponent("Button", isDirectory: true)
        let previewFile = buttonDirectory.appendingPathComponent("P+Disabled.swift")

        try FileManager.default.createDirectory(at: buttonDirectory, withIntermediateDirectories: true)
        try """
        import SwiftUI

        #if DEBUG
        struct DisabledWithReasonPreviews: View {
            var body: some View {
                Text("Hello")
            }
        }

        #Preview("Button Disabled with Reason") {
            DisabledWithReasonPreviews()
        }
        #endif
        """.write(to: previewFile, atomically: true, encoding: .utf8)
        try """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "MagicKit",
            platforms: [.macOS(.v14)],
            products: [
                .library(name: "MagicKit", targets: ["MagicKit"]),
            ],
            dependencies: [],
            targets: [
                .target(
                    name: "MagicKit",
                    dependencies: [],
                    resources: [.process("Icons.xcassets")]
                ),
                .testTarget(
                    name: "Tests",
                    dependencies: ["MagicKit"]
                )
            ]
        )
        """.write(to: packageDirectory.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: packageDirectory) }

        let result = LumiPreviewFacade.BuildPlanner().plan(for: previewFile)

        guard case let .spm(_, targetName) = result else {
            Issue.record("Expected .spm strategy for MagicKit file with resources, got \(String(describing: result))")
            return
        }

        #expect(targetName == "MagicKit")
    }

    @Test("target 同时声明 resources 和 sources 时，两者都能被正确解析")
    func spmTargetWithResourcesAndSourcesParsedCorrectly() throws {
        let packageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-ResourcesAndSources-\(UUID().uuidString)", isDirectory: true)
        let targetDirectory = packageDirectory.appendingPathComponent("MyFeature", isDirectory: true)
        let includedDirectory = targetDirectory.appendingPathComponent("Core", isDirectory: true)
        let resourcesDirectory = targetDirectory.appendingPathComponent("Assets", isDirectory: true)
        let includedFile = includedDirectory.appendingPathComponent("Feature.swift")
        let resourceFile = resourcesDirectory.appendingPathComponent("data.json")

        try FileManager.default.createDirectory(at: includedDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)
        try "struct Feature {}\n".write(to: includedFile, atomically: true, encoding: .utf8)
        try "{}\n".write(to: resourceFile, atomically: true, encoding: .utf8)
        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "MixedPackage",
            targets: [
                .target(
                    name: "FeatureTarget",
                    path: "MyFeature",
                    sources: ["Core"],
                    resources: [.process("Assets")]
                )
            ]
        )
        """.write(to: packageDirectory.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: packageDirectory) }

        let result = LumiPreviewFacade.BuildPlanner().plan(for: includedFile)

        guard case let .spm(_, targetName) = result else {
            Issue.record("Expected .spm strategy, got \(String(describing: result))")
            return
        }

        #expect(targetName == "FeatureTarget")
    }

    private func writeXcodeProject(
        at projectURL: URL,
        targetName: String,
        sourceFiles: [URL],
        sourceTree: String = "<group>"
    ) throws {
        let sourceDirectory = sourceFiles[0].deletingLastPathComponent()
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        for sourceFile in sourceFiles {
            try "struct \(sourceFile.deletingPathExtension().lastPathComponent) {}\n"
                .write(to: sourceFile, atomically: true, encoding: .utf8)
        }

        let groupPath = sourceTree == "SOURCE_ROOT"
            ? sourceDirectory.path.replacingOccurrences(of: projectURL.deletingLastPathComponent().path + "/", with: "")
            : sourceDirectory.lastPathComponent
        let sourceEntries = sourceFiles.enumerated().map { index, file in
            let fileID = "AAAAAAA\(index + 1)"
            let buildFileID = "BBBBBBB\(index + 1)"
            let path = sourceTree == "SOURCE_ROOT"
                ? sourceDirectory.appendingPathComponent(file.lastPathComponent).path
                    .replacingOccurrences(of: projectURL.deletingLastPathComponent().path + "/", with: "")
                : file.lastPathComponent
            return (fileID, buildFileID, path)
        }
        let fileObjects = sourceEntries.map { fileID, _, path in
            """
            \t\t\(fileID) /* \(path) */ = {
            \t\t\tisa = PBXFileReference;
            \t\t\tlastKnownFileType = sourcecode.swift;
            \t\t\tpath = \(path);
            \t\t\tsourceTree = "\(sourceTree)";
            \t\t};
            """
        }.joined(separator: "\n")
        let buildFileObjects = sourceEntries.map { fileID, buildFileID, path in
            """
            \t\t\(buildFileID) /* \(path) in Sources */ = {
            \t\t\tisa = PBXBuildFile;
            \t\t\tfileRef = \(fileID) /* \(path) */;
            \t\t};
            """
        }.joined(separator: "\n")
        let fileIDs = sourceEntries.map(\.0).joined(separator: ",\n\t\t\t\t")
        let buildFileIDs = sourceEntries.map(\.1).joined(separator: ",\n\t\t\t\t")

        try """
        // !$*UTF8*$!
        {
        \tarchiveVersion = 1;
        \tclasses = {};
        \tobjectVersion = 77;
        \tobjects = {
        \(buildFileObjects)
        \(fileObjects)
        \t\tCCCCCCCC /* Sources */ = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (
        \t\t\t\t\(fileIDs),
        \t\t\t);
        \t\t\tpath = \(groupPath);
        \t\t\tsourceTree = "\(sourceTree)";
        \t\t};
        \t\tDDDDDDDD /* Sources */ = {
        \t\t\tisa = PBXSourcesBuildPhase;
        \t\t\tfiles = (
        \t\t\t\t\(buildFileIDs),
        \t\t\t);
        \t\t};
        \t\tEEEEEEEE /* \(targetName) */ = {
        \t\t\tisa = PBXNativeTarget;
        \t\t\tbuildPhases = (
        \t\t\t\tDDDDDDDD,
        \t\t\t);
        \t\t\tname = \(targetName);
        \t\t};
        \t};
        \trootObject = EEEEEEEE;
        }
        """.write(to: projectURL.appendingPathComponent("project.pbxproj"), atomically: true, encoding: .utf8)
    }

    // MARK: - skipDescendants 回归测试

    @Test("排除普通文件时 skipDescendants 不应影响同级目录遍历")
    func excludingRegularFileShouldNotSkipSiblingDirectories() throws {
        // 直接验证：当 excludedPaths 指向一个普通文件（Info.plist）时，
        // 遍历仍应收集到字母序排在其后的目录（Plugins/）中的 Swift 文件。
        //
        // 此测试验证 swiftSourceFiles(in:excluding:) 的核心行为——
        // 对普通文件不应调用 skipDescendants()，因为在 macOS 上
        // skipDescendants() 对文件调用会产生副作用，导致后续同级目录被跳过。
        //
        // 目录结构（模拟 Lumi 项目）：
        //   root/
        //     Core/
        //       Bootstrap/
        //         AutomationController.swift
        //     Info.plist              ← 排除项
        //     Plugins/
        //       EditorPanelPlugin.swift

        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-SkipDescendants-\(UUID().uuidString)", isDirectory: true)
        let coreBootstrap = rootDirectory.appendingPathComponent("Core/Bootstrap", isDirectory: true)
        let pluginsDirectory = rootDirectory.appendingPathComponent("Plugins", isDirectory: true)

        let automationFile = coreBootstrap.appendingPathComponent("AutomationController.swift")
        let editorPluginFile = pluginsDirectory.appendingPathComponent("EditorPanelPlugin.swift")
        let infoPlist = rootDirectory.appendingPathComponent("Info.plist")

        try FileManager.default.createDirectory(at: coreBootstrap, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: pluginsDirectory, withIntermediateDirectories: true)
        try "struct AutomationController {}\n".write(to: automationFile, atomically: true, encoding: .utf8)
        try "struct EditorPlugin {}\n".write(to: editorPluginFile, atomically: true, encoding: .utf8)
        try "<plist/>".write(to: infoPlist, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let root = rootDirectory.standardizedFileURL.resolvingSymlinksInPath()
        let excluded = [infoPlist.standardizedFileURL.resolvingSymlinksInPath()]

        let sources = LumiPreviewFacade.BuildPlanner.swiftSourceFiles(
            in: [root],
            excluding: excluded
        )

        let names = Set(sources.map { $0.lastPathComponent })
        #expect(names.contains("AutomationController.swift"),
                "Core/Bootstrap/AutomationController.swift should be collected")
        #expect(names.contains("EditorPanelPlugin.swift"),
                "Plugins/EditorPanelPlugin.swift should be collected even though Info.plist (excluded regular file) precedes it alphabetically")
        #expect(sources.count == 2)
    }

    @Test("Xcode synchronized group 排除普通文件时收集所有子目录源码")
    func xcodeSyncedGroupExcludingPlainFileCollectsAllSubdirectories() throws {
        // 端到端测试：通过 Xcode 项目结构验证排除普通文件后仍能收集所有子目录
        //   APP/
        //     Core/
        //       AutomationController.swift  (引用 EditorPlugin)
        //     Info.plist                    ← 排除项
        //     Plugins/
        //       EditorPanelPlugin.swift     (定义 EditorPlugin)

        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-XcodeSyncSkip-\(UUID().uuidString)", isDirectory: true)
        let projectURL = rootDirectory.appendingPathComponent("SyncedApp.xcodeproj", isDirectory: true)
        let appDirectory = rootDirectory.appendingPathComponent("APP", isDirectory: true)
        let coreDirectory = appDirectory.appendingPathComponent("Core", isDirectory: true)
        let pluginsDirectory = appDirectory.appendingPathComponent("Plugins", isDirectory: true)

        let automationFile = coreDirectory.appendingPathComponent("AutomationController.swift")
        let editorPluginFile = pluginsDirectory.appendingPathComponent("EditorPanelPlugin.swift")
        let infoPlist = appDirectory.appendingPathComponent("Info.plist")

        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: coreDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: pluginsDirectory, withIntermediateDirectories: true)
        try "import Foundation\nstruct AutomationController { let icon = EditorPlugin.iconName }\n"
            .write(to: automationFile, atomically: true, encoding: .utf8)
        try "import Foundation\nstruct EditorPlugin { static let iconName = \"editor\" }\n"
            .write(to: editorPluginFile, atomically: true, encoding: .utf8)
        try "<plist/>".write(to: infoPlist, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        try """
        // !$*UTF8*$!
        {
        \tarchiveVersion = 1;
        \tclasses = {};
        \tobjectVersion = 77;
        \tobjects = {
        \t\t000000000000000000000001 = {
        \t\t\tisa = PBXNativeTarget;
        \t\t\tbuildPhases = ();
        \t\t\tfileSystemSynchronizedGroups = (
        \t\t\t\t000000000000000000000002,
        \t\t\t);
        \t\t\tname = SyncedApp;
        \t\t};
        \t\t000000000000000000000002 /* APP */ = {
        \t\t\tisa = PBXFileSystemSynchronizedRootGroup;
        \t\t\texceptions = (
        \t\t\t\t000000000000000000000003,
        \t\t\t);
        \t\t\tpath = APP;
        \t\t\tsourceTree = "<group>";
        \t\t};
        \t\t000000000000000000000003 = {
        \t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;
        \t\t\tmembershipExceptions = (
        \t\t\t\tInfo.plist,
        \t\t\t);
        \t\t\ttarget = 000000000000000000000001;
        \t\t};
        \t};
        \trootObject = 000000000000000000000001;
        }
        """.write(to: projectURL.appendingPathComponent("project.pbxproj"), atomically: true, encoding: .utf8)

        let sources = LumiPreviewFacade.BuildPlanner.swiftSourceFiles(
            projectURL: projectURL,
            scheme: "SyncedApp",
            containing: automationFile
        )

        let names = Set(sources.map { $0.lastPathComponent })
        #expect(names.contains("AutomationController.swift"),
                "Core/AutomationController.swift should be collected")
        #expect(names.contains("EditorPanelPlugin.swift"),
                "Plugins/EditorPanelPlugin.swift must be collected")
        #expect(sources.count == 2)
    }

    @Test("排除目录时仍然正确调用 skipDescendants")
    func excludingDirectoryShouldStillSkipDescendants() throws {
        // 验证修复后，排除目录时 skipDescendants 仍然生效
        // 使用 swiftSourceFiles(in:excluding:) 直接验证，
        // 不走 Xcode 项目路径（augmentedXcodeSources 会绕过排除列表）
        //
        //   APP/
        //     A.swift
        //     Excluded/
        //       ignored.swift
        //     Kept/
        //       B.swift

        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-SkipDir-\(UUID().uuidString)", isDirectory: true)
        let appDirectory = rootDirectory.appendingPathComponent("APP", isDirectory: true)
        let excludedDirectory = appDirectory.appendingPathComponent("Excluded", isDirectory: true)
        let keptDirectory = appDirectory.appendingPathComponent("Kept", isDirectory: true)

        let fileA = appDirectory.appendingPathComponent("A.swift")
        let ignoredFile = excludedDirectory.appendingPathComponent("ignored.swift")
        let fileB = keptDirectory.appendingPathComponent("B.swift")

        try FileManager.default.createDirectory(at: excludedDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: keptDirectory, withIntermediateDirectories: true)
        try "struct A {}\n".write(to: fileA, atomically: true, encoding: .utf8)
        try "struct Ignored {}\n".write(to: ignoredFile, atomically: true, encoding: .utf8)
        try "struct B {}\n".write(to: fileB, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let root = appDirectory.standardizedFileURL.resolvingSymlinksInPath()
        let excluded = [excludedDirectory.standardizedFileURL.resolvingSymlinksInPath()]

        let sources = LumiPreviewFacade.BuildPlanner.swiftSourceFiles(
            in: [root],
            excluding: excluded
        )

        let names = Set(sources.map { $0.lastPathComponent })
        #expect(names.contains("A.swift"), "A.swift should be collected")
        #expect(names.contains("B.swift"), "Kept/B.swift should be collected")
        #expect(!names.contains("ignored.swift"), "Excluded/ignored.swift should NOT be collected")
        #expect(sources.count == 2)
    }

    @Test("5.4 bare directory without Package.swift returns nil")
    func bareDirectoryWithoutPackageReturnsNil() throws {
        let directory = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = try TemporaryProjectFixtures.writeSwiftFileWithPreview(
            at: directory.appendingPathComponent("Loose.swift"),
            previewLabel: "Loose"
        )

        let strategy = LumiPreviewFacade.BuildPlanner().plan(for: fileURL)
        #expect(strategy == nil)
    }

    @Test("5.5 multiple sibling xcodeproj directories do not crash planner")
    func multipleSiblingXcodeProjectsDoNotCrash() throws {
        let directory = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (_, _, swiftFile) = try TemporaryProjectFixtures.makeDualXcodeProjects(in: directory)

        let strategy = LumiPreviewFacade.BuildPlanner().plan(for: swiftFile)
        #expect(strategy == nil || strategy != nil)
    }

    @Test("5.6 package with binary target does not crash planner")
    func packageWithBinaryTargetDoesNotCrash() throws {
        let directory = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let packageDirectory = directory
        let sources = packageDirectory
            .appendingPathComponent("Sources/App", isDirectory: true)
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        let fileURL = sources.appendingPathComponent("App.swift")
        try TemporaryProjectFixtures.writeSwiftFileWithPreview(at: fileURL, previewLabel: "App")
        let manifest = """
        // swift-tools-version: 5.9
        import PackageDescription

        let package = Package(
            name: "BinaryPkg",
            platforms: [.macOS(.v14)],
            targets: [
                .binaryTarget(name: "External", path: "Artifacts/External.xcframework"),
                .target(name: "App", dependencies: ["External"], path: "Sources/App")
            ]
        )
        """
        try manifest.write(
            to: packageDirectory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let strategy = LumiPreviewFacade.BuildPlanner().plan(for: fileURL)
        if case .spm(let packageURL, let targetName) = strategy {
            #expect(packageURL == packageDirectory)
            #expect(targetName == "App")
        } else {
            Issue.record("Expected SPM strategy, got \(String(describing: strategy))")
        }
    }

}
