import Testing
import Foundation
@testable import XcodeProjectGen

@Suite("XcodeProjectSpecResolver Tests")
struct XcodeProjectSpecResolverTests {

    /// 创建临时目录用于测试。
    private func createTempDirectory() throws -> String {
        let tempDir = NSTemporaryDirectory() + "XcodeProjectGenResolverTests_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// 清理临时目录。
    private func cleanup(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("扫描空目录")
    func scanEmptyDirectory() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let resolver = XcodeProjectSpecResolver()
        let result = try resolver.scan(projectRoot: tempDir)

        #expect(result.sources.isEmpty)
        #expect(result.resources.isEmpty)
    }

    @Test("扫描包含 Swift 文件的目录")
    func scanDirectoryWithSwiftFiles() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let sourcesDir = tempDir + "/Sources/MyApp"
        try FileManager.default.createDirectory(atPath: sourcesDir, withIntermediateDirectories: true)
        try "import Foundation\n".write(toFile: sourcesDir + "/main.swift", atomically: true, encoding: .utf8)
        try "import Foundation\n".write(toFile: sourcesDir + "/Model.swift", atomically: true, encoding: .utf8)

        let resolver = XcodeProjectSpecResolver()
        let result = try resolver.scanSources(in: sourcesDir, relativeTo: tempDir)

        #expect(result.count == 2)
        #expect(result.contains { $0.hasSuffix("main.swift") })
        #expect(result.contains { $0.hasSuffix("Model.swift") })
    }

    @Test("扫描排除隐藏目录")
    func scanExcludesHiddenDirectories() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        // 创建 .build 目录（应该被排除）
        let buildDir = tempDir + "/Sources/MyApp/.build"
        try FileManager.default.createDirectory(atPath: buildDir, withIntermediateDirectories: true)
        try "bad".write(toFile: buildDir + "/generated.swift", atomically: true, encoding: .utf8)

        // 创建正常文件
        try "good".write(toFile: tempDir + "/Sources/MyApp/main.swift", atomically: true, encoding: .utf8)

        let resolver = XcodeProjectSpecResolver()
        let result = try resolver.scanSources(in: tempDir + "/Sources/MyApp", relativeTo: tempDir)

        #expect(result.count == 1)
        #expect(result[0].hasSuffix("main.swift"))
    }

    @Test("扫描排除 .git 目录")
    func scanExcludesGitDirectory() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let gitDir = tempDir + "/Sources/App/.git"
        try FileManager.default.createDirectory(atPath: gitDir, withIntermediateDirectories: true)
        try "".write(toFile: gitDir + "/index", atomically: true, encoding: .utf8)

        try "import Foundation".write(toFile: tempDir + "/Sources/App/App.swift", atomically: true, encoding: .utf8)

        let resolver = XcodeProjectSpecResolver()
        let result = try resolver.scanSources(in: tempDir + "/Sources/App", relativeTo: tempDir)

        #expect(result.count == 1)
    }

    @Test("扫描资源文件")
    func scanResourceFiles() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        // 创建资源目录
        let resourcesDir = tempDir + "/Resources"
        try FileManager.default.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true)

        // 创建 xcassets
        let assetsDir = resourcesDir + "/Assets.xcassets"
        try FileManager.default.createDirectory(atPath: assetsDir, withIntermediateDirectories: true)

        // 创建 strings 文件
        try "\"key\" = \"value\";".write(toFile: resourcesDir + "/Localizable.strings", atomically: true, encoding: .utf8)

        let resolver = XcodeProjectSpecResolver()
        let result = try resolver.scanResources(in: resourcesDir, relativeTo: tempDir)

        #expect(!result.isEmpty)
    }

    @Test("扫描项目根目录级别")
    func scanProjectRootLevel() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        // 创建典型项目结构
        let sourcesDir = tempDir + "/Sources/MyApp"
        let resourcesDir = tempDir + "/Resources"
        try FileManager.default.createDirectory(atPath: sourcesDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true)
        try "".write(toFile: sourcesDir + "/main.swift", atomically: true, encoding: .utf8)

        // 创建 .xcodeproj（应该被排除）
        let xcodeproj = tempDir + "/Test.xcodeproj"
        try FileManager.default.createDirectory(atPath: xcodeproj, withIntermediateDirectories: true)

        let resolver = XcodeProjectSpecResolver()
        let result = try resolver.scan(projectRoot: tempDir)

        // Sources 目录应该被发现包含源文件
        #expect(result.sources.contains("Sources"))
        // Resources 目录应该被发现
        #expect(result.resources.contains("Resources"))
    }

    @Test("扫描结果排序")
    func scanResultsAreSorted() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let dir = tempDir + "/Sources"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try "".write(toFile: dir + "/Zebra.swift", atomically: true, encoding: .utf8)
        try "".write(toFile: dir + "/Alpha.swift", atomically: true, encoding: .utf8)
        try "".write(toFile: dir + "/Middle.swift", atomically: true, encoding: .utf8)

        let resolver = XcodeProjectSpecResolver()
        let result = try resolver.scanSources(in: dir, relativeTo: tempDir)

        #expect(result == result.sorted())
    }

    @Test("扫描相对路径只移除项目根目录前缀")
    func scanRelativePathOnlyDropsProjectRootPrefix() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let repeatedRootFragment = tempDir.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let sourcesDir = tempDir + "/Sources/tmp/" + repeatedRootFragment
        try FileManager.default.createDirectory(atPath: sourcesDir, withIntermediateDirectories: true)
        try "".write(toFile: sourcesDir + "/Feature.swift", atomically: true, encoding: .utf8)

        let resolver = XcodeProjectSpecResolver()
        let result = try resolver.scanSources(in: tempDir + "/Sources", relativeTo: tempDir)

        #expect(result == ["Sources/tmp/\(repeatedRootFragment)/Feature.swift"])
    }

    @Test("扫描相对路径拒绝同前缀兄弟目录")
    func scanRelativePathRejectsSiblingWithSharedPrefix() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }
        let siblingDir = tempDir + "-copy/Sources"
        defer { cleanup(tempDir + "-copy") }

        try FileManager.default.createDirectory(atPath: siblingDir, withIntermediateDirectories: true)
        try "".write(toFile: siblingDir + "/Feature.swift", atomically: true, encoding: .utf8)

        let resolver = XcodeProjectSpecResolver()
        let result = try resolver.scanSources(in: siblingDir, relativeTo: tempDir)

        #expect(result == ["Feature.swift"])
    }
}
