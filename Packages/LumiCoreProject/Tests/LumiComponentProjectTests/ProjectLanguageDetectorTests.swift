import Foundation
import LumiCoreProject
import Testing

/// `ProjectLanguageDetector` 的单元测试。
///
/// 用临时目录模拟项目根，写入 marker 文件后验证探测结果。每个测试自己清理临时目录。
@MainActor
struct ProjectLanguageDetectorTests {
    /// 创建一个临时项目目录，可选地写入若干文件。
    private func makeProjectDir(files: [String] = []) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiLangDetect-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for name in files {
            let fileURL = dir.appendingPathComponent(name)
            let content = name == "package.json" ? Self.emptyPackageJSON : ""
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        return dir
    }

    private static let emptyPackageJSON = #"{"name":"x","version":"1.0.0"}"#

    @Test func detectsSwiftByPackageSwift() throws {
        let dir = try makeProjectDir(files: ["Package.swift"])
        #expect(ProjectLanguageDetector.detect(at: dir.path) == .swift)
    }

    @Test func detectsGoByGoMod() throws {
        let dir = try makeProjectDir(files: ["go.mod"])
        #expect(ProjectLanguageDetector.detect(at: dir.path) == .go)
    }

    @Test func detectsRustByCargoToml() throws {
        let dir = try makeProjectDir(files: ["Cargo.toml"])
        #expect(ProjectLanguageDetector.detect(at: dir.path) == .rust)
    }

    @Test func detectsPythonByPyproject() throws {
        let dir = try makeProjectDir(files: ["pyproject.toml"])
        #expect(ProjectLanguageDetector.detect(at: dir.path) == .python)
    }

    @Test func detectsPythonBySetupPy() throws {
        let dir = try makeProjectDir(files: ["setup.py"])
        #expect(ProjectLanguageDetector.detect(at: dir.path) == .python)
    }

    @Test func detectsJavaScriptForPlainPackageJSON() throws {
        let dir = try makeProjectDir(files: ["package.json"])
        #expect(ProjectLanguageDetector.detect(at: dir.path) == .javascript)
    }

    @Test func detectsTypeScriptWhenTypeScriptDepPresent() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiLangDetect-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let pkg = #"""
        {
          "name": "x",
          "dependencies": { "typescript": "^5.0.0" }
        }
        """#
        try pkg.write(to: dir.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        #expect(ProjectLanguageDetector.detect(at: dir.path) == .typescript)
    }

    @Test func detectsTypeScriptWhenAtTypesNodePresent() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiLangDetect-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let pkg = #"""
        {
          "name": "x",
          "devDependencies": { "@types/node": "^20.0.0" }
        }
        """#
        try pkg.write(to: dir.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        #expect(ProjectLanguageDetector.detect(at: dir.path) == .typescript)
    }

    @Test func returnsUnknownForEmptyDirectory() throws {
        let dir = try makeProjectDir(files: [])
        #expect(ProjectLanguageDetector.detect(at: dir.path) == .unknown)
    }

    @Test func returnsUnknownForNonexistentPath() {
        #expect(ProjectLanguageDetector.detect(at: "/nonexistent/path/xyz") == .unknown)
    }

    @Test func singleFileMarkerTakesPriorityOverPackageJSON() throws {
        // 同时有 Package.swift 和 package.json 时，应优先识别为 swift。
        let dir = try makeProjectDir(files: ["Package.swift", "package.json"])
        #expect(ProjectLanguageDetector.detect(at: dir.path) == .swift)
    }

    // MARK: - ProjectEntry Codable 向后兼容

    @Test func entryDecodesWithoutLanguageFieldAsUnknown() throws {
        // 模拟旧数据：JSON 里没有 language 字段。
        let json = #"{"name":"old","path":"/tmp/old","lastUsed":700000000}"#
        let entry = try JSONDecoder().decode(ProjectEntry.self, from: json.data(using: .utf8)!)
        #expect(entry.language == .unknown)
        #expect(entry.name == "old")
    }

    @Test func entryRoundTripsLanguageThroughEncoding() throws {
        let entry = ProjectEntry(name: "p", path: "/tmp/p", language: .go)
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(ProjectEntry.self, from: data)
        #expect(decoded.language == .go)
    }

    @Test func entryInitDefaultsLanguageToUnknown() {
        // 旧调用点不传 language 时应默认 .unknown。
        let entry = ProjectEntry(name: "p", path: "/tmp/p")
        #expect(entry.language == .unknown)
    }
}
