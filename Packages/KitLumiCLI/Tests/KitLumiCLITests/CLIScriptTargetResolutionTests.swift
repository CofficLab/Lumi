import Foundation
import Testing

@testable import KitLumiCLI

/// 截取生成脚本中「解析目标目录 → 编码 URL」的片段实跑，验证相对文件路径
/// 必须解析为绝对路径（回归 #491）。
struct CLIScriptTargetResolutionTests {
    private func makeTargetURL(arguments: [String], workingDirectory: URL) throws -> String? {
        let script = CLIScriptBuilder.scriptContents(appPath: "/Applications/Lumi.app")
        let lines = script.split(separator: "\n", omittingEmptySubsequences: false)
        guard let start = lines.firstIndex(where: { $0.contains("# --- 解析目标目录") }),
              let end = lines.firstIndex(where: { $0.contains("# --- 交给 Launch Services") }) else {
            Issue.record("生成的脚本缺少目标解析段")
            return nil
        }
        let fragment = lines[start..<end].joined(separator: "\n")
            + "\necho \"$TARGET_URL\"\nexit 0\n"

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kitlumicli-resolution-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fragmentURL = directory.appendingPathComponent("fragment.sh")
        try fragment.write(to: fragmentURL, atomically: true, encoding: .utf8)

        let stdout = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [fragmentURL.path] + arguments
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Test("相对文件路径编码进 URL 前必须解析为绝对路径（回归 #491）")
    func relativeFilePathResolvesToAbsolutePath() throws {
        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kitlumicli-cwd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workingDirectory) }
        try Data("swift".utf8).write(to: workingDirectory.appendingPathComponent("Package.swift"))

        let url = try makeTargetURL(arguments: ["Package.swift"], workingDirectory: workingDirectory)

        let expectedEncoded = (workingDirectory.path
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")
            .replacingOccurrences(of: "/", with: "%2F")
        #expect(url != nil)
        #expect(url?.contains(expectedEncoded + "%2FPackage.swift") == true)
        #expect(url?.contains("path=Package.swift") != true)
    }

    @Test("相对目录路径保持既有行为，编码绝对路径")
    func relativeDirectoryPathStillResolves() throws {
        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kitlumicli-cwd-\(UUID().uuidString)", isDirectory: true)
        let nested = workingDirectory.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workingDirectory) }

        let url = try makeTargetURL(arguments: ["project"], workingDirectory: workingDirectory)

        let expectedEncoded = (nested.path
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")
            .replacingOccurrences(of: "/", with: "%2F")
        #expect(url != nil)
        #expect(url?.contains(expectedEncoded) == true)
    }

    @Test("不存在的路径必须非零退出，不得把相对路径交给 App（回归 #491）")
    func missingPathExitsNonZero() throws {
        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kitlumicli-cwd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workingDirectory) }

        let script = CLIScriptBuilder.scriptContents(appPath: "/Applications/Lumi.app")
        let lines = script.split(separator: "\n", omittingEmptySubsequences: false)
        guard let start = lines.firstIndex(where: { $0.contains("# --- 解析目标目录") }),
              let end = lines.firstIndex(where: { $0.contains("# --- 编码为 URL") }) else {
            Issue.record("生成的脚本缺少目标解析段")
            return
        }
        let fragment = lines[start..<end].joined(separator: "\n") + "\n"

        let fragmentURL = workingDirectory.appendingPathComponent("fragment.sh")
        try fragment.write(to: fragmentURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [fragmentURL.path, "missing.txt"]
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus != 0)
    }
}
