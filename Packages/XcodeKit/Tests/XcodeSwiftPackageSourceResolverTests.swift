import XCTest
import XcodeProj
@testable import XcodeKit

final class SwiftPackageManifestParserTests: XCTestCase {

    func testLocalPackageDependencyPathsResolvesRelativePaths() throws {
        let root = try makeTemporaryPackageRoot {
            """
            // swift-tools-version: 6.0
            import PackageDescription

            let package = Package(
                name: "Registry",
                products: [
                    .library(name: "Registry", targets: ["Registry"])
                ],
                dependencies: [
                    .package(path: "../Feature"),
                    .package(path: "../../Shared/Core"),
                ],
                targets: [
                    .target(name: "Registry", path: "Sources")
                ]
            )
            """
        }
        let feature = root.appendingPathComponent("Feature")
        let sharedCore = root.deletingLastPathComponent().appendingPathComponent("Shared/Core")
        try FileManager.default.createDirectory(at: feature, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sharedCore, withIntermediateDirectories: true)
        try writePackageManifest(at: feature, name: "Feature")
        try writePackageManifest(at: sharedCore, name: "Core")

        let paths = SwiftPackageManifestParser.localPackageDependencyPaths(packageRoot: root)

        XCTAssertEqual(
            Set(paths.map(\.lastPathComponent)),
            ["Feature", "Core"]
        )
    }

    func testLocalTransitivePackageRootsIncludesNestedDependencies() throws {
        let root = try makeTemporaryPackageRoot {
            """
            // swift-tools-version: 6.0
            import PackageDescription

            let package = Package(
                name: "AppSupport",
                products: [
                    .library(name: "AppSupport", targets: ["AppSupport"])
                ],
                dependencies: [
                    .package(path: "Packages/Feature"),
                ],
                targets: [
                    .target(name: "AppSupport", path: "Sources")
                ]
            )
            """
        }
        let feature = root.appendingPathComponent("Packages/Feature")
        let core = root.appendingPathComponent("Packages/Core")
        try FileManager.default.createDirectory(at: feature, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
        try writePackageManifest(
            at: feature,
            name: "Feature",
            extraDependencies: #".package(path: "../Core"),"#
        )
        try writePackageManifest(at: core, name: "Core")

        let roots = SwiftPackageManifestParser.localTransitivePackageRoots(from: root)

        XCTAssertTrue(roots.contains(root.standardizedFileURL))
        XCTAssertTrue(roots.contains(feature.standardizedFileURL))
        XCTAssertTrue(roots.contains(core.standardizedFileURL))
    }

    func testRegularTargetSourceRootsUsesSharedSourcesDirectory() throws {
        let root = try makeTemporaryPackageRoot {
            """
            // swift-tools-version: 6.0
            import PackageDescription

            let package = Package(
                name: "Feature",
                products: [
                    .library(name: "Feature", targets: ["Feature"])
                ],
                targets: [
                    .target(
                        name: "Feature",
                        dependencies: [],
                        path: "Sources"
                    )
                ]
            )
            """
        }
        let sourceFile = root.appendingPathComponent("Sources/Feature.swift")
        try FileManager.default.createDirectory(at: sourceFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "struct Feature {}".write(to: sourceFile, atomically: true, encoding: .utf8)

        let roots = SwiftPackageManifestParser.regularTargetSourceRoots(packageRoot: root)

        XCTAssertEqual(roots, [SwiftPackageManifestParser.TargetSourceRoot(relativePath: "Sources", excludedRelativePaths: [])])
    }

    // MARK: - Helpers

    private func makeTemporaryPackageRoot(manifest: () -> String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        try manifest().write(to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        return root
    }

    private func writePackageManifest(
        at root: URL,
        name: String,
        extraDependencies: String = ""
    ) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let manifest = """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "\(name)",
            products: [
                .library(name: "\(name)", targets: ["\(name)"])
            ],
            dependencies: [
                \(extraDependencies)
            ],
            targets: [
                .target(name: "\(name)", path: "Sources")
            ]
        )
        """
        try manifest.write(to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
    }
}

final class XcodeSwiftPackageSourceResolverTests: XCTestCase {

    func testEnumeratePackageSourceFilesIncludesSwiftFilesInSources() throws {
        let root = try makePackage(
            name: "Feature",
            manifest: """
            // swift-tools-version: 6.0
            import PackageDescription

            let package = Package(
                name: "Feature",
                products: [
                    .library(name: "Feature", targets: ["Feature"])
                ],
                targets: [
                    .target(name: "Feature", path: "Sources")
                ]
            )
            """
        )
        let file = root.appendingPathComponent("Sources/Feature.swift")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "struct Feature {}".write(to: file, atomically: true, encoding: .utf8)

        let files = XcodeSwiftPackageSourceResolver.enumeratePackageSourceFiles(packageRoot: root)

        XCTAssertTrue(files.contains(file.standardizedFileURL.path))
    }

    func testResolveTargetSourceFilesIncludesTransitiveSwiftPackageSources() throws {
        let root = try makeTemporaryProject()
        let projectURL = root.appendingPathComponent("App.xcodeproj")
        let xcodeProj = try XcodeProj(pathString: projectURL.path)
        let project = try xcodeProj.pbxproj.rootProject() ?? xcodeProj.pbxproj.projects.first
        XCTAssertNotNil(project)
        XCTAssertEqual(project?.targets.first?.packageProductDependencies?.map(\.productName), ["Registry"])

        let result = XcodeProjectResolver.resolveTargetSourceFiles(projectLikeURL: projectURL)

        let featureFile = root
            .appendingPathComponent("Packages/Feature/Sources/Feature.swift")
            .standardizedFileURL
            .path
        XCTAssertTrue(result["App"]?.contains(featureFile) == true, "Result files: \(result["App"] ?? [])")
    }

    func testLumiProjectIncludesTransitivePluginSources() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectURL = repoRoot.appendingPathComponent("Lumi.xcodeproj")
        guard FileManager.default.fileExists(atPath: projectURL.path) else {
            throw XCTSkip("Lumi.xcodeproj is unavailable in this environment")
        }

        let result = XcodeProjectResolver.resolveTargetSourceFiles(projectLikeURL: projectURL)
        let pluginFile = repoRoot
            .appendingPathComponent("Plugins/EditorBottomProblemsPlugin/Sources/EditorBottomProblemsPlugin.swift")
            .path
        let memoryPluginFile = repoRoot
            .appendingPathComponent("Plugins/MemoryPlugin/Sources/MemoryPlugin.swift")
            .path

        XCTAssertTrue(result["Lumi"]?.contains(pluginFile) == true, "Expected EditorBottomProblemsPlugin to belong to Lumi target")
        XCTAssertTrue(result["Lumi"]?.contains(memoryPluginFile) == true, "Expected MemoryPlugin to belong to Lumi target")
    }

    // MARK: - Helpers

    private func makePackage(name: String, manifest: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        try manifest.write(to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        return root
    }

    private func makeTemporaryProject() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }

        let appSources = root.appendingPathComponent("App/Sources")
        try FileManager.default.createDirectory(at: appSources, withIntermediateDirectories: true)
        try "import Foundation".write(
            to: appSources.appendingPathComponent("main.swift"),
            atomically: true,
            encoding: .utf8
        )

        let registry = root.appendingPathComponent("Packages/Registry")
        let feature = root.appendingPathComponent("Packages/Feature")
        try FileManager.default.createDirectory(at: registry.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: feature.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try "public struct Registry {}".write(
            to: registry.appendingPathComponent("Sources/Registry.swift"),
            atomically: true,
            encoding: .utf8
        )
        try "public struct Feature {}".write(
            to: feature.appendingPathComponent("Sources/Feature.swift"),
            atomically: true,
            encoding: .utf8
        )

        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "Registry",
            products: [
                .library(name: "Registry", targets: ["Registry"])
            ],
            dependencies: [
                .package(path: "../Feature"),
            ],
            targets: [
                .target(name: "Registry", path: "Sources")
            ]
        )
        """.write(to: registry.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "Feature",
            products: [
                .library(name: "Feature", targets: ["Feature"])
            ],
            targets: [
                .target(name: "Feature", path: "Sources")
            ]
        )
        """.write(to: feature.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        let projectURL = root.appendingPathComponent("App.xcodeproj")
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try minimalPBXProj().write(to: projectURL.appendingPathComponent("project.pbxproj"), atomically: true, encoding: .utf8)
        return root
    }

    private func minimalPBXProj() -> String {
        """
        // !$*UTF8*$!
        {
        \tarchiveVersion = 1;
        \tclasses = {};
        \tobjectVersion = 77;
        \tobjects = {
        /* Begin PBXFileSystemSynchronizedRootGroup section */
        \t\tAPPGRP000000000000001 /* App */ = {
        \t\t\tisa = PBXFileSystemSynchronizedRootGroup;
        \t\t\tpath = App;
        \t\t\tsourceTree = "<group>";
        \t\t};
        /* End PBXFileSystemSynchronizedRootGroup section */
        /* Begin PBXFrameworksBuildPhase section */
        \t\tAPPFRM000000000000001 /* Frameworks */ = {
        \t\t\tisa = PBXFrameworksBuildPhase;
        \t\t\tbuildActionMask = 2147483647;
        \t\t\tfiles = (
        \t\t\t);
        \t\t\trunOnlyForDeploymentPostprocessing = 0;
        \t\t};
        /* End PBXFrameworksBuildPhase section */
        /* Begin PBXGroup section */
        \t\tAPPGRP000000000000002 = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (
        \t\t\t\tAPPGRP000000000000001 /* App */,
        \t\t\t);
        \t\t\tsourceTree = "<group>";
        \t\t};
        /* End PBXGroup section */
        /* Begin PBXNativeTarget section */
        \t\tAPPTGT000000000000001 /* App */ = {
        \t\t\tisa = PBXNativeTarget;
        \t\t\tbuildConfigurationList = APPCFG000000000000003 /* Build configuration list for PBXNativeTarget "App" */;
        \t\t\tbuildPhases = (
        \t\t\t\tAPPSRC000000000000001 /* Sources */,
        \t\t\t\tAPPFRM000000000000001 /* Frameworks */,
        \t\t\t);
        \t\t\tbuildRules = (
        \t\t\t);
        \t\t\tdependencies = (
        \t\t\t);
        \t\t\tfileSystemSynchronizedGroups = (
        \t\t\t\tAPPGRP000000000000001 /* App */,
        \t\t\t);
        \t\t\tname = App;
        \t\t\tpackageProductDependencies = (
        \t\t\t\tPKGPRD000000000000001 /* Registry */,
        \t\t\t);
        \t\t\tproductName = App;
        \t\t\tproductType = "com.apple.product-type.application";
        \t\t};
        /* End PBXNativeTarget section */
        /* Begin PBXProject section */
        \t\tAPPPRO000000000000001 /* Project object */ = {
        \t\t\tisa = PBXProject;
        \t\t\tbuildConfigurationList = APPCFG000000000000002 /* Build configuration list for PBXProject "App" */;
        \t\t\tcompatibilityVersion = "Xcode 16.0";
        \t\t\tdevelopmentRegion = en;
        \t\t\thasScannedForEncodings = 0;
        \t\t\tknownRegions = (
        \t\t\t\ten,
        \t\t\t);
        \t\t\tmainGroup = APPGRP000000000000002;
        \t\t\tminimizedProjectReferenceProxies = 1;
        \t\t\tpackageReferences = (
        \t\t\t\tPKGREF000000000000001 /* XCLocalSwiftPackageReference "Packages/Registry" */,
        \t\t\t);
        \t\t\tpreferredProjectObjectVersion = 77;
        \t\t\tproductRefGroup = APPGRP000000000000002;
        \t\t\tprojectDirPath = "";
        \t\t\tprojectRoot = "";
        \t\t\ttargets = (
        \t\t\t\tAPPTGT000000000000001 /* App */,
        \t\t\t);
        \t\t};
        /* End PBXProject section */
        /* Begin PBXSourcesBuildPhase section */
        \t\tAPPSRC000000000000001 /* Sources */ = {
        \t\t\tisa = PBXSourcesBuildPhase;
        \t\t\tbuildActionMask = 2147483647;
        \t\t\tfiles = (
        \t\t\t);
        \t\t\trunOnlyForDeploymentPostprocessing = 0;
        \t\t};
        /* End PBXSourcesBuildPhase section */
        /* Begin XCBuildConfiguration section */
        \t\tAPPCFG000000000000004 /* Debug */ = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
        \t\t\t};
        \t\t\tname = Debug;
        \t\t};
        \t\tAPPCFG000000000000005 /* Release */ = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
        \t\t\t};
        \t\t\tname = Release;
        \t\t};
        \t\tAPPCFG000000000000006 /* Debug */ = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t};
        \t\t\tname = Debug;
        \t\t};
        \t\tAPPCFG000000000000007 /* Release */ = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t};
        \t\t\tname = Release;
        \t\t};
        /* End XCBuildConfiguration section */
        /* Begin XCConfigurationList section */
        \t\tAPPCFG000000000000002 /* Build configuration list for PBXProject "App" */ = {
        \t\t\tisa = XCConfigurationList;
        \t\t\tbuildConfigurations = (
        \t\t\t\tAPPCFG000000000000006 /* Debug */,
        \t\t\t\tAPPCFG000000000000007 /* Release */,
        \t\t\t);
        \t\t\tdefaultConfigurationIsVisible = 0;
        \t\t\tdefaultConfigurationName = Release;
        \t\t};
        \t\tAPPCFG000000000000003 /* Build configuration list for PBXNativeTarget "App" */ = {
        \t\t\tisa = XCConfigurationList;
        \t\t\tbuildConfigurations = (
        \t\t\t\tAPPCFG000000000000004 /* Debug */,
        \t\t\t\tAPPCFG000000000000005 /* Release */,
        \t\t\t);
        \t\t\tdefaultConfigurationIsVisible = 0;
        \t\t\tdefaultConfigurationName = Release;
        \t\t};
        /* End XCConfigurationList section */
        /* Begin XCLocalSwiftPackageReference section */
        \t\tPKGREF000000000000001 /* XCLocalSwiftPackageReference "Packages/Registry" */ = {
        \t\t\tisa = XCLocalSwiftPackageReference;
        \t\t\trelativePath = Packages/Registry;
        \t\t};
        /* End XCLocalSwiftPackageReference section */
        /* Begin XCSwiftPackageProductDependency section */
        \t\tPKGPRD000000000000001 /* Registry */ = {
        \t\t\tisa = XCSwiftPackageProductDependency;
        \t\t\tpackage = PKGREF000000000000001 /* XCLocalSwiftPackageReference "Packages/Registry" */;
        \t\t\tproductName = Registry;
        \t\t};
        /* End XCSwiftPackageProductDependency section */
        \t};
        \trootObject = APPPRO000000000000001 /* Project object */;
        }
        """
    }
}
