import XCTest
@testable import ProjectProfileKit

final class ProjectProfilerTests: XCTestCase {
    private var temporaryRoots: [URL] = []

    override func tearDownWithError() throws {
        try temporaryRoots.forEach { root in
            if FileManager.default.fileExists(atPath: root.path) {
                try FileManager.default.removeItem(at: root)
            }
        }
        temporaryRoots.removeAll()
        try super.tearDownWithError()
    }

    func testReturnsNilForMissingDirectory() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        XCTAssertNil(ProjectProfiler().profile(projectPath: missing.path))
    }

    func testPackageJSONDetectsTypeScriptDependenciesFrameworksAndWebType() throws {
        let root = try makeProject()
        try write(
            """
            {
              "dependencies": {
                "react": "18.2.0",
                "vite": "5.0.0"
              },
              "devDependencies": {
                "typescript": "5.4.0",
                "electron": "30.0.0"
              }
            }
            """,
            to: root.appendingPathComponent("package.json")
        )
        try write(
            """
            # Example Web App

            A focused developer dashboard for preview workflows.
            React preview dashboard dashboard workflows workflows workflows.
            """,
            to: root.appendingPathComponent("README.md")
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.projectPath, root.standardizedFileURL.path)
        XCTAssertEqual(profile.primaryLanguage, "TypeScript")
        XCTAssertEqual(profile.projectType, .web)
        XCTAssertEqual(profile.frameworks, ["Electron", "React", "Vite"])
        XCTAssertTrue(profile.dependencies.contains("react"))
        XCTAssertTrue(profile.dependencies.contains("vite"))
        XCTAssertTrue(profile.dependencies.contains("typescript"))
        XCTAssertEqual(profile.description, "A focused developer dashboard for preview workflows.")
        XCTAssertTrue(profile.keywords.contains("dashboard"))
        XCTAssertFalse(profile.keywords.contains("the"))
    }

    func testSwiftPackageDetectsSwiftDependenciesPlatformAndSDKType() throws {
        let root = try makeProject()
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Sources"),
            withIntermediateDirectories: true
        )
        try write(
            #"""
            // swift-tools-version: 6.0
            import PackageDescription

            let package = Package(
                name: "PreviewKit",
                dependencies: [
                    .package(url: "https://github.com/example/RenderKit.git", from: "1.0.0")
                ],
                targets: [
                    .target(
                        name: "PreviewKit",
                        dependencies: ["RenderKit"]
                    )
                ]
            )

            import SwiftUI
            import Combine
            """#,
            to: root.appendingPathComponent("Package.swift")
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.primaryLanguage, "Swift")
        XCTAssertEqual(profile.projectType, .sdk)
        XCTAssertEqual(profile.platform, "Apple platforms")
        XCTAssertTrue(profile.dependencies.contains("RenderKit"))
        XCTAssertTrue(profile.dependencies.contains("SwiftUI"))
        XCTAssertTrue(profile.dependencies.contains("Combine"))
    }

    func testSwiftPackageReadsUTF16ManifestDependencies() throws {
        let root = try makeProject()
        try write(
            #"""
            // swift-tools-version: 6.0
            import PackageDescription

            let package = Package(
                name: "PreviewKit",
                dependencies: [
                    .package(url: "https://github.com/example/RenderKit.git", from: "1.0.0")
                ]
            )

            import SwiftUI
            """#,
            to: root.appendingPathComponent("Package.swift"),
            encoding: .utf16
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.primaryLanguage, "Swift")
        XCTAssertTrue(profile.dependencies.contains("RenderKit"))
        XCTAssertTrue(profile.dependencies.contains("SwiftUI"))
        XCTAssertEqual(profile.platform, "Apple platforms")
    }

    func testXcodeProjectAndSwiftSourcesDetectSwiftAppleFrameworksAndMobileType() throws {
        let root = try makeProject()
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("App.xcodeproj"),
            withIntermediateDirectories: true
        )
        let sourceDirectory = root.appendingPathComponent("LumiApp/Views")
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try write(
            """
            import SwiftUI
            import AppKit

            struct RootView: View {
                var body: some View {
                    Text("Hello")
                }
            }
            """,
            to: sourceDirectory.appendingPathComponent("RootView.swift")
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.primaryLanguage, "Swift")
        XCTAssertEqual(profile.projectType, .mobile)
        XCTAssertEqual(profile.platform, "Apple platforms")
        XCTAssertTrue(profile.frameworks.contains("SwiftUI"))
        XCTAssertTrue(profile.frameworks.contains("AppKit"))
    }

    func testNestedSwiftPackagesContributeSwiftLanguageAndDependencies() throws {
        let root = try makeProject()
        let packageDirectory = root.appendingPathComponent("Packages/RenderKit")
        try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
        try write(
            #"""
            // swift-tools-version: 6.0
            import PackageDescription

            let package = Package(
                name: "RenderKit",
                dependencies: [
                    .package(url: "https://github.com/example/GraphicsCore.git", from: "1.0.0")
                ]
            )
            """#,
            to: packageDirectory.appendingPathComponent("Package.swift")
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.primaryLanguage, "Swift")
        XCTAssertEqual(profile.projectType, .unknown)
        XCTAssertTrue(profile.dependencies.contains("GraphicsCore"))
    }

    func testRecursiveSourceScanDetectsDominantLanguageWithoutManifest() throws {
        let root = try makeProject()
        let sourceDirectory = root.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try write("print('one')", to: sourceDirectory.appendingPathComponent("one.py"))
        try write("print('two')", to: sourceDirectory.appendingPathComponent("two.py"))
        try write("console.log('three')", to: sourceDirectory.appendingPathComponent("three.js"))

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.primaryLanguage, "Python")
        XCTAssertEqual(profile.projectType, .sdk)
    }

    func testSourceScanIgnoresBuildAndDependencyDirectories() throws {
        let root = try makeProject()
        let buildDirectory = root.appendingPathComponent(".build/checkouts/Generated")
        let nodeModulesDirectory = root.appendingPathComponent("node_modules/demo")
        try FileManager.default.createDirectory(at: buildDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nodeModulesDirectory, withIntermediateDirectories: true)
        try write("import SwiftUI", to: buildDirectory.appendingPathComponent("Generated.swift"))
        try write("console.log('ignored')", to: nodeModulesDirectory.appendingPathComponent("index.js"))

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertNil(profile.primaryLanguage)
        XCTAssertEqual(profile.frameworks, [])
    }

    func testPodfileDetectsMobileProjectDependenciesAndPlatform() throws {
        let root = try makeProject()
        try write(
            """
            platform :ios, '17.0'
            target 'App' do
              pod 'Alamofire'
              pod "Kingfisher"
            end
            """,
            to: root.appendingPathComponent("Podfile")
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.primaryLanguage, "Swift")
        XCTAssertEqual(profile.projectType, .mobile)
        XCTAssertEqual(profile.platform, "ios")
        XCTAssertEqual(profile.dependencies, ["Alamofire", "Kingfisher"])
    }

    func testGoModDetectsGoDirectRequireLines() throws {
        let root = try makeProject()
        try write(
            """
            module github.com/example/server

            require github.com/gin-gonic/gin v1.10.0
            require github.com/spf13/cobra v1.8.1
            """,
            to: root.appendingPathComponent("go.mod")
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("bin"),
            withIntermediateDirectories: true
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.primaryLanguage, "Go")
        XCTAssertEqual(profile.projectType, .cli)
        XCTAssertEqual(profile.dependencies, ["github.com/gin-gonic/gin", "github.com/spf13/cobra"])
    }

    func testGoModDetectsRequireBlocksWithIndirectDependencies() throws {
        let root = try makeProject()
        try write(
            """
            module github.com/example/server

            require (
                github.com/gin-gonic/gin v1.10.0
                github.com/spf13/cobra v1.8.1
                golang.org/x/sys v0.30.0 // indirect
            )
            """,
            to: root.appendingPathComponent("go.mod")
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("cmd"),
            withIntermediateDirectories: true
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.primaryLanguage, "Go")
        XCTAssertEqual(profile.dependencies, [
            "github.com/gin-gonic/gin",
            "github.com/spf13/cobra",
            "golang.org/x/sys",
        ])
    }

    func testCargoTomlDetectsRustDependencies() throws {
        let root = try makeProject()
        try write(
            """
            [package]
            name = "cli"

            [dependencies]
            serde = "1"
            tokio = { version = "1", features = ["full"] }

            [dev-dependencies]
            tempfile = "3"
            """,
            to: root.appendingPathComponent("Cargo.toml")
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.primaryLanguage, "Rust")
        XCTAssertEqual(profile.projectType, .unknown)
        XCTAssertEqual(profile.dependencies, ["serde", "tokio"])
    }

    func testPythonRequirementsDetectsDependencies() throws {
        let root = try makeProject()
        try write(
            """
            fastapi==0.110.0
            uvicorn[standard]>=0.29.0
            # comment
            requests ~= 2.31
            """,
            to: root.appendingPathComponent("requirements.txt")
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.primaryLanguage, "Python")
        XCTAssertEqual(profile.projectType, .unknown)
        XCTAssertEqual(profile.dependencies, ["fastapi", "requests", "uvicorn[standard]"])
    }

    func testPyprojectDetectsPEP621Dependencies() throws {
        let root = try makeProject()
        try write(
            """
            [project]
            dependencies = [
                "fastapi>=0.110.0",
                "uvicorn[standard]>=0.29.0 ; python_version >= '3.11'",
            ]

            [project.optional-dependencies]
            test = [
                'pytest>=8',
                'pytest-cov ~= 5.0',
            ]
            """,
            to: root.appendingPathComponent("pyproject.toml")
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.primaryLanguage, "Python")
        XCTAssertEqual(profile.dependencies, [
            "fastapi",
            "pytest",
            "pytest-cov",
            "uvicorn[standard]",
        ])
    }

    func testPyprojectDetectsPoetryDependencies() throws {
        let root = try makeProject()
        try write(
            """
            [tool.poetry.dependencies]
            python = "^3.12"
            django = "^5.0"
            httpx = { version = "^0.27", extras = ["http2"] }

            [tool.poetry.group.dev.dependencies]
            ruff = "^0.8"
            """,
            to: root.appendingPathComponent("pyproject.toml")
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.primaryLanguage, "Python")
        XCTAssertEqual(profile.dependencies, ["django", "httpx", "ruff"])
    }

    func testKotlinBuildFilesDetectLanguageWithoutDependencies() throws {
        let root = try makeProject()
        try write(
            """
            plugins {
                kotlin("jvm") version "2.0.0"
            }
            """,
            to: root.appendingPathComponent("build.gradle")
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.primaryLanguage, "Kotlin")
        XCTAssertEqual(profile.dependencies, [])
        XCTAssertEqual(profile.frameworks, [])
    }

    func testREADMEFallbackUsesHeadingWhenNoBodyDescriptionExists() throws {
        let root = try makeProject()
        try write(
            """
            # Heading Only

            ![Screenshot](image.png)
            """,
            to: root.appendingPathComponent("README.md")
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.description, "Heading Only")
        XCTAssertTrue(profile.keywords.contains("heading"))
    }

    func testReadmeReadsUTF16DescriptionAndKeywords() throws {
        let root = try makeProject()
        try write(
            """
            # UTF16 README

            A focused preview dashboard for workflows.
            Dashboard dashboard workflows workflows.
            """,
            to: root.appendingPathComponent("README.md"),
            encoding: .utf16
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.description, "A focused preview dashboard for workflows.")
        XCTAssertTrue(profile.keywords.contains("dashboard"))
        XCTAssertTrue(profile.keywords.contains("workflows"))
    }

    func testReadmeDescriptionIsLimitedToTwoHundredFortyCharacters() throws {
        let root = try makeProject()
        let description = String(repeating: "a", count: 300)
        try write(description, to: root.appendingPathComponent("README.md"))

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.description.count, 240)
    }

    func testLanguageWeightPrefersSwiftPackageOverPackageJSON() throws {
        let root = try makeProject()
        try write(#"{"dependencies":{"react":"18.2.0"}}"#, to: root.appendingPathComponent("package.json"))
        try write(
            """
            // swift-tools-version: 6.0
            import PackageDescription
            let package = Package(name: "Mixed")
            """,
            to: root.appendingPathComponent("Package.swift")
        )

        let profile = try XCTUnwrap(ProjectProfiler().profile(projectPath: root.path))

        XCTAssertEqual(profile.primaryLanguage, "Swift")
        XCTAssertEqual(profile.projectType, .web)
        XCTAssertTrue(profile.frameworks.contains("React"))
    }

    private func makeProject() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectProfileKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        temporaryRoots.append(root)
        return root
    }

    private func write(_ text: String, to url: URL, encoding: String.Encoding = .utf8) throws {
        try text.write(to: url, atomically: true, encoding: encoding)
    }
}
