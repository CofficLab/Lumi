import Foundation

/// SPM 编译器：使用 swift build 编译 SPM Package 中的预览。
public final class SPMCompiler: Sendable {
    /// 创建 SPM 编译器。
    public init() {}

    /// 编译指定 target，返回编译产物路径。
    ///
    /// - Parameters:
    ///   - packageDirectory: 包含 `Package.swift` 的目录。
    ///   - targetName: 需要编译的 SwiftPM target 名称。
    /// - Returns: 可作为编译完成标记的产物路径。
    public func build(packageDirectory: URL, targetName: String) async throws -> URL {
        try await Task.detached {
            let result = try Self.runSwiftBuild(packageDirectory: packageDirectory, targetName: targetName)

            guard result.terminationStatus == 0 else {
                throw PreviewError.compilationFailed(message: Self.failureMessage(from: result))
            }

            guard let productURL = Self.findBuildProduct(
                packageDirectory: packageDirectory,
                targetName: targetName
            ) else {
                throw PreviewError.buildProductNotFound
            }

            return productURL
        }.value
    }

    private struct BuildResult: Sendable {
        let terminationStatus: Int32
        let stdout: String
        let stderr: String
    }

    private static func runSwiftBuild(packageDirectory: URL, targetName: String) throws -> BuildResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "build", "--target", targetName]
        process.currentDirectoryURL = packageDirectory

        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-SPMCompiler-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        let stdoutURL = outputDirectory.appendingPathComponent("stdout.log")
        let stderrURL = outputDirectory.appendingPathComponent("stderr.log")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)

        guard let stdoutHandle = try? FileHandle(forWritingTo: stdoutURL),
              let stderrHandle = try? FileHandle(forWritingTo: stderrURL) else {
            throw PreviewError.compilationFailed(message: "Failed to capture swift build output.")
        }
        defer {
            try? stdoutHandle.close()
            try? stderrHandle.close()
        }

        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        do {
            try process.run()
        } catch {
            throw PreviewError.compilationFailed(message: "Failed to launch swift build: \(error.localizedDescription)")
        }

        process.waitUntilExit()

        let stdout = (try? String(contentsOf: stdoutURL, encoding: .utf8)) ?? ""
        let stderr = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""

        return BuildResult(
            terminationStatus: process.terminationStatus,
            stdout: stdout,
            stderr: stderr
        )
    }

    private static func findBuildProduct(packageDirectory: URL, targetName: String) -> URL? {
        let fileManager = FileManager.default
        let buildDirectory = packageDirectory.appendingPathComponent(".build", isDirectory: true)
        let debugDirectories = candidateDebugDirectories(in: buildDirectory)

        for debugDirectory in debugDirectories {
            for candidate in finalProductCandidates(targetName: targetName, debugDirectory: debugDirectory) {
                if fileManager.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        for debugDirectory in debugDirectories {
            let buildDirectory = debugDirectory.appendingPathComponent("\(targetName).build", isDirectory: true)
            if fileManager.fileExists(atPath: buildDirectory.path) {
                return buildDirectory
            }
        }

        return nil
    }

    private static func candidateDebugDirectories(in buildDirectory: URL) -> [URL] {
        let fileManager = FileManager.default
        var directories = [buildDirectory.appendingPathComponent("debug", isDirectory: true)]

        guard let entries = try? fileManager.contentsOfDirectory(
            at: buildDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return directories
        }

        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }

            let debugDirectory = entry.appendingPathComponent("debug", isDirectory: true)
            if fileManager.fileExists(atPath: debugDirectory.path) {
                directories.append(debugDirectory)
            }
        }

        return directories
    }

    private static func finalProductCandidates(targetName: String, debugDirectory: URL) -> [URL] {
        [
            debugDirectory.appendingPathComponent(targetName),
            debugDirectory.appendingPathComponent("lib\(targetName).dylib"),
            debugDirectory.appendingPathComponent("lib\(targetName).a"),
            debugDirectory.appendingPathComponent("Modules", isDirectory: true)
                .appendingPathComponent("\(targetName).swiftmodule")
        ]
    }

    private static func failureMessage(from result: BuildResult) -> String {
        let combinedOutput = [result.stderr, result.stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard !combinedOutput.isEmpty else {
            return "swift build failed with exit code \(result.terminationStatus)"
        }

        let diagnosticLines = combinedOutput
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                line.contains(": error:")
                    || line.contains("error:")
                    || line.contains("no such module")
                    || line.contains("unknown target")
            }

        if !diagnosticLines.isEmpty {
            return diagnosticLines.joined(separator: "\n")
        }

        return combinedOutput
    }
}
