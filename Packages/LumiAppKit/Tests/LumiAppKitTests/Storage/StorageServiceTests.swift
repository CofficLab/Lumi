import Foundation
import Testing
@testable import LumiAppKit

/// `StorageService.majorVersion(from:)` 的纯函数测试
///
/// 该函数从 `CFBundleShortVersionString` 中提取主版本号，
/// 解析失败时回退到 1。
struct StorageServiceMajorVersionTests {

    @Test
    func nilVersionReturnsOne() {
        let value = StorageService.majorVersion(from: nil)
        #expect(value == 1)
    }

    @Test
    func emptyStringReturnsOne() {
        let value = StorageService.majorVersion(from: "")
        #expect(value == 1)
    }

    @Test
    func nonNumericPrefixReturnsOne() {
        let value = StorageService.majorVersion(from: "abc.2.3")
        #expect(value == 1)
    }

    @Test
    func standardSemverReturnsMajor() {
        let value = StorageService.majorVersion(from: "1.2.3")
        #expect(value == 1)
    }

    @Test
    func twoDigitMajorReturnsCorrectly() {
        let value = StorageService.majorVersion(from: "12.0.0")
        #expect(value == 12)
    }

    @Test
    func largeMajorReturnsCorrectly() {
        let value = StorageService.majorVersion(from: "999.0.0")
        #expect(value == 999)
    }

    @Test
    func singleSegmentIsTreatedAsMajor() {
        let value = StorageService.majorVersion(from: "5")
        #expect(value == 5)
    }
}

/// `StorageService.makeCoreDatabaseDirectory(in:)` 的文件系统级测试
struct StorageServiceCoreDirectoryTests {

    /// 在临时目录下创建 Core 子目录的辅助函数
    private func makeTemporaryRoot() throws -> URL {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiAppKit-Tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempRoot,
            withIntermediateDirectories: true
        )
        return tempRoot
    }

    @Test
    func createsCoreSubdirectory() throws {
        // Given
        let tempRoot = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        // When
        let coreDirectory = StorageService.makeCoreDatabaseDirectory(in: tempRoot)

        // Then
        #expect(coreDirectory.lastPathComponent == "Core")
        #expect(coreDirectory.deletingLastPathComponent() == tempRoot)
        #expect(FileManager.default.fileExists(atPath: coreDirectory.path))
    }

    @Test
    func isIdempotentWhenCalledTwice() throws {
        let tempRoot = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let first = StorageService.makeCoreDatabaseDirectory(in: tempRoot)
        let second = StorageService.makeCoreDatabaseDirectory(in: tempRoot)

        #expect(first == second)
        #expect(FileManager.default.fileExists(atPath: second.path))
    }

    @Test
    func appendsCoreComponentToGivenRoot() {
        let fakeRoot = URL(fileURLWithPath: "/tmp/LumiAppKit-FakeRoot", isDirectory: true)
        let coreDirectory = StorageService.makeCoreDatabaseDirectory(in: fakeRoot)

        #expect(coreDirectory.path == "/tmp/LumiAppKit-FakeRoot/Core")
    }
}

/// `StorageService.makeDataRootDirectory()` 的行为测试
///
/// 该函数依赖 `Bundle.main`，在测试环境（无主 App bundle）中
/// 会回退到 `com.coffic.Lumi` bundle id。我们验证：
/// 1. 返回路径是 Application Support 下的子路径；
/// 2. 目录确实被创建出来；
/// 3. 目录名符合 `db_<mode>_v<major>` 模式。
struct StorageServiceDataRootDirectoryTests {

    @Test
    func createsDirectoryUnderApplicationSupport() throws {
        let url = StorageService.makeDataRootDirectory()

        let appSupport = try #require(
            FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first
        )
        #expect(url.path.hasPrefix(appSupport.path))
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func directoryNameFollowsVersionedPattern() throws {
        let url = StorageService.makeDataRootDirectory()
        let lastComponent = url.lastPathComponent

        // 期望形如 db_debug_vN 或 db_production_vN
        let pattern = #"^db_(debug|production)_v\d+$"#
        let regex = try Regex(pattern)
        #expect(lastComponent.wholeMatch(of: regex) != nil)
    }
}