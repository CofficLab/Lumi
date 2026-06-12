import Testing
import Foundation
@testable import XcodeProjectGen

@Suite("XcodeProjectGenerator Tests")
struct XcodeProjectGeneratorTests {

    /// 创建临时目录用于测试。
    private func createTempDirectory() throws -> String {
        let tempDir = NSTemporaryDirectory() + "XcodeProjectGenTests_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// 清理临时目录。
    private func cleanup(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("生成简单 App 项目")
    func generateSimpleAppProject() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        // 创建源文件
        let sourcesDir = tempDir + "/Sources/MyApp"
        try FileManager.default.createDirectory(atPath: sourcesDir, withIntermediateDirectories: true)
        try "import Foundation\n".write(toFile: sourcesDir + "/main.swift", atomically: true, encoding: .utf8)

        let spec = XcodeProjectSpec(
            name: "MyApp",
            targets: [
                .app(
                    name: "MyApp",
                    platform: .iOS,
                    deploymentTarget: "17.0",
                    sources: ["Sources/MyApp"],
                    settings: [
                        .bundleIdentifier("com.example.MyApp"),
                        .developmentTeam("ABC123"),
                    ]
                )
            ]
        )

        let generator = XcodeProjectGenerator()
        let resultPath = try generator.generate(spec: spec, projectRoot: tempDir)

        // 验证 .xcodeproj 目录已创建
        #expect(FileManager.default.fileExists(atPath: resultPath))
        #expect(resultPath.hasSuffix(".xcodeproj"))

        // 验证 project.pbxproj 存在
        let pbxprojPath = resultPath + "/project.pbxproj"
        #expect(FileManager.default.fileExists(atPath: pbxprojPath))

        // 读取 pbxproj 验证内容
        let content = try String(contentsOfFile: pbxprojPath, encoding: .utf8)
        #expect(content.contains("MyApp"))
        #expect(content.contains("com.apple.product-type.application"))
        #expect(content.contains("com.example.MyApp"))
    }

    @Test("生成带 Framework 依赖的项目")
    func generateProjectWithFrameworkDependency() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        // 创建源文件
        let appSources = tempDir + "/Sources/App"
        let coreSources = tempDir + "/Sources/Core"
        try FileManager.default.createDirectory(atPath: appSources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: coreSources, withIntermediateDirectories: true)
        try "import Foundation\n".write(toFile: appSources + "/App.swift", atomically: true, encoding: .utf8)
        try "import Foundation\n".write(toFile: coreSources + "/Core.swift", atomically: true, encoding: .utf8)

        let spec = XcodeProjectSpec(
            name: "MyProject",
            targets: [
                .app(
                    name: "MyApp",
                    platform: .iOS,
                    deploymentTarget: "17.0",
                    sources: ["Sources/App"],
                    dependencies: [.target(name: "MyCore")],
                    settings: [.bundleIdentifier("com.example.MyApp")]
                ),
                .framework(
                    name: "MyCore",
                    sources: ["Sources/Core"]
                )
            ]
        )

        let generator = XcodeProjectGenerator()
        let resultPath = try generator.generate(spec: spec, projectRoot: tempDir)

        let content = try String(contentsOfFile: resultPath + "/project.pbxproj", encoding: .utf8)
        #expect(content.contains("MyApp"))
        #expect(content.contains("MyCore"))
        #expect(content.contains("com.apple.product-type.framework"))
    }

    @Test("验证 Spec - 空 Target 列表抛出错误")
    func validationEmptyTargets() throws {
        let spec = XcodeProjectSpec(name: "Test", targets: [])
        let generator = XcodeProjectGenerator()

        #expect(throws: XcodeProjectGenError.self) {
            try generator.generate(spec: spec, projectRoot: "/tmp")
        }
    }

    @Test("验证 Spec - 空名称抛出错误")
    func validationEmptyName() throws {
        let spec = XcodeProjectSpec(name: "", targets: [
            .app(name: "App")
        ])
        let generator = XcodeProjectGenerator()

        #expect(throws: XcodeProjectGenError.self) {
            try generator.generate(spec: spec, projectRoot: "/tmp")
        }
    }

    @Test("验证 Spec - 重复 Target 名称抛出错误")
    func validationDuplicateTargetNames() throws {
        let spec = XcodeProjectSpec(name: "Test", targets: [
            .app(name: "App"),
            .framework(name: "App"), // 重复
        ])
        let generator = XcodeProjectGenerator()

        #expect(throws: XcodeProjectGenError.self) {
            try generator.generate(spec: spec, projectRoot: "/tmp")
        }
    }

    @Test("验证 Spec - 不存在的 Target 依赖抛出错误")
    func validationMissingTargetDependency() throws {
        let spec = XcodeProjectSpec(name: "Test", targets: [
            .app(
                name: "App",
                dependencies: [.target(name: "NonExistent")]
            ),
        ])
        let generator = XcodeProjectGenerator()

        #expect(throws: XcodeProjectGenError.self) {
            try generator.generate(spec: spec, projectRoot: "/tmp")
        }
    }

    @Test("验证 Spec - 项目根目录不存在抛出错误")
    func validationProjectRootNotFound() throws {
        let spec = XcodeProjectSpec(name: "Test", targets: [
            .app(name: "App"),
        ])
        let generator = XcodeProjectGenerator()

        #expect(throws: XcodeProjectGenError.self) {
            try generator.generate(spec: spec, projectRoot: "/nonexistent/path/12345")
        }
    }

    @Test("生成带 Scheme 的项目")
    func generateProjectWithSchemes() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let sourcesDir = tempDir + "/Sources/MyApp"
        try FileManager.default.createDirectory(atPath: sourcesDir, withIntermediateDirectories: true)
        try "".write(toFile: sourcesDir + "/main.swift", atomically: true, encoding: .utf8)

        let spec = XcodeProjectSpec(
            name: "MyApp",
            targets: [
                .app(
                    name: "MyApp",
                    sources: ["Sources/MyApp"],
                    settings: [.bundleIdentifier("com.example.MyApp")]
                )
            ],
            schemes: [
                XcodeSchemeSpec(name: "MyApp", buildTargets: ["MyApp"])
            ]
        )

        let generator = XcodeProjectGenerator()
        let resultPath = try generator.generate(spec: spec, projectRoot: tempDir)

        // 验证 Scheme 文件存在
        let schemePath = resultPath + "/xcshareddata/xcschemes/MyApp.xcscheme"
        #expect(FileManager.default.fileExists(atPath: schemePath))

        let schemeContent = try String(contentsOfFile: schemePath, encoding: .utf8)
        #expect(schemeContent.contains("MyApp"))
    }

    @Test("生成带测试 Target 的项目")
    func generateProjectWithTestTarget() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let appSources = tempDir + "/Sources/App"
        let testSources = tempDir + "/Tests/AppTests"
        try FileManager.default.createDirectory(atPath: appSources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: testSources, withIntermediateDirectories: true)
        try "".write(toFile: appSources + "/App.swift", atomically: true, encoding: .utf8)
        try "".write(toFile: testSources + "/AppTests.swift", atomically: true, encoding: .utf8)

        let spec = XcodeProjectSpec(
            name: "MyApp",
            targets: [
                .app(
                    name: "MyApp",
                    sources: ["Sources/App"],
                    settings: [.bundleIdentifier("com.example.MyApp")]
                ),
                .unitTest(
                    name: "MyAppTests",
                    sources: ["Tests/AppTests"],
                    targetDependency: "MyApp"
                )
            ]
        )

        let generator = XcodeProjectGenerator()
        let resultPath = try generator.generate(spec: spec, projectRoot: tempDir)

        let content = try String(contentsOfFile: resultPath + "/project.pbxproj", encoding: .utf8)
        #expect(content.contains("MyApp"))
        #expect(content.contains("MyAppTests"))
        #expect(content.contains("com.apple.product-type.bundle.unit-test"))
    }

    @Test("生成 macOS 项目")
    func generateMacOSProject() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let sourcesDir = tempDir + "/Sources/MyCLI"
        try FileManager.default.createDirectory(atPath: sourcesDir, withIntermediateDirectories: true)
        try "".write(toFile: sourcesDir + "/main.swift", atomically: true, encoding: .utf8)

        let spec = XcodeProjectSpec(
            name: "MyCLI",
            targets: [
                XcodeTargetSpec(
                    name: "MyCLI",
                    kind: .app,
                    platform: .macOS,
                    deploymentTarget: "14.0",
                    sources: ["Sources/MyCLI"],
                    settings: [.bundleIdentifier("com.example.MyCLI")]
                )
            ]
        )

        let generator = XcodeProjectGenerator()
        let resultPath = try generator.generate(spec: spec, projectRoot: tempDir)

        let content = try String(contentsOfFile: resultPath + "/project.pbxproj", encoding: .utf8)
        #expect(content.contains("macosx"))
        #expect(content.contains("MACOSX_DEPLOYMENT_TARGET"))
    }

    @Test("生成项目文件引用路径只移除项目根目录前缀")
    func generateProjectFileReferencesOnlyDropProjectRootPrefix() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let repeatedRootFragment = tempDir.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let sourcesDir = tempDir + "/Sources/tmp/" + repeatedRootFragment
        try FileManager.default.createDirectory(atPath: sourcesDir, withIntermediateDirectories: true)
        try "".write(toFile: sourcesDir + "/Feature.swift", atomically: true, encoding: .utf8)

        let spec = XcodeProjectSpec(
            name: "NestedPaths",
            targets: [
                .app(
                    name: "NestedPaths",
                    platform: .macOS,
                    sources: ["Sources"],
                    settings: [.bundleIdentifier("com.example.NestedPaths")]
                )
            ]
        )

        let generator = XcodeProjectGenerator()
        let resultPath = try generator.generate(spec: spec, projectRoot: tempDir)
        let content = try String(contentsOfFile: resultPath + "/project.pbxproj", encoding: .utf8)

        #expect(content.contains("Sources/tmp/\(repeatedRootFragment)/Feature.swift"))
    }
}
