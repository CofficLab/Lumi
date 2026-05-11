import Foundation

/// Xcode 编译器：使用 xcodebuild 编译 Xcode 项目中的预览。
public final class XcodeCompiler: Sendable {
    /// 创建 Xcode 编译器。
    public init() {}

    /// 编译指定 scheme，返回编译产物路径。
    ///
    /// - Parameters:
    ///   - projectURL: `.xcodeproj` 或 `.xcworkspace` 路径。
    ///   - scheme: 要编译的 scheme。
    ///   - configuration: 编译配置，默认 `Debug`。
    /// - Returns: Xcode 构建产物路径。
    public func build(
        projectURL: URL,
        scheme: String,
        configuration: String = "Debug"
    ) async throws -> URL {
        try await Task.detached {
            let buildResult = try Self.runXcodebuild(
                projectURL: projectURL,
                scheme: scheme,
                configuration: configuration,
                action: "build"
            )

            guard buildResult.terminationStatus == 0 else {
                throw PreviewError.compilationFailed(message: Self.failureMessage(from: buildResult))
            }

            let settingsResult = try Self.runXcodebuild(
                projectURL: projectURL,
                scheme: scheme,
                configuration: configuration,
                action: "-showBuildSettings"
            )

            guard settingsResult.terminationStatus == 0 else {
                throw PreviewError.compilationFailed(message: Self.failureMessage(from: settingsResult))
            }

            let buildSettings = Self.parseBuildSettings(settingsResult.stdout)
            guard let productURL = Self.findBuildProduct(from: buildSettings) else {
                throw PreviewError.buildProductNotFound
            }

            return productURL
        }.value
    }

    /// 从 build log 中提取指定文件的 `swift-frontend` 编译命令。
    ///
    /// - Parameters:
    ///   - fileURL: 需要增量编译的 Swift 文件。
    ///   - buildLog: `xcodebuild` 输出日志。
    /// - Returns: 匹配到的完整编译命令；未找到时返回 `nil`。
    public func extractCompileCommand(for fileURL: URL, buildLog: String) -> String? {
        let filePath = fileURL.standardizedFileURL.path
        return buildLog
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .first { line in
                line.contains("swift-frontend")
                    && (line.contains(filePath) || line.contains(fileURL.lastPathComponent))
            }
    }

    private struct BuildResult: Sendable {
        let terminationStatus: Int32
        let stdout: String
        let stderr: String
    }

    private static func runXcodebuild(
        projectURL: URL,
        scheme: String,
        configuration: String,
        action: String
    ) throws -> BuildResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments(
            projectURL: projectURL,
            scheme: scheme,
            configuration: configuration,
            action: action
        )
        process.currentDirectoryURL = projectURL.deletingLastPathComponent()

        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-XcodeCompiler-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        let stdoutURL = outputDirectory.appendingPathComponent("stdout.log")
        let stderrURL = outputDirectory.appendingPathComponent("stderr.log")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)

        guard let stdoutHandle = try? FileHandle(forWritingTo: stdoutURL),
              let stderrHandle = try? FileHandle(forWritingTo: stderrURL) else {
            throw PreviewError.compilationFailed(message: "Failed to capture xcodebuild output.")
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
            throw PreviewError.compilationFailed(message: "Failed to launch xcodebuild: \(error.localizedDescription)")
        }

        process.waitUntilExit()

        return BuildResult(
            terminationStatus: process.terminationStatus,
            stdout: (try? String(contentsOf: stdoutURL, encoding: .utf8)) ?? "",
            stderr: (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
        )
    }

    private static func arguments(
        projectURL: URL,
        scheme: String,
        configuration: String,
        action: String
    ) -> [String] {
        var arguments = ["xcodebuild"]

        if projectURL.pathExtension == "xcworkspace" {
            arguments.append(contentsOf: ["-workspace", projectURL.path])
        } else {
            arguments.append(contentsOf: ["-project", projectURL.path])
        }

        arguments.append(contentsOf: [
            "-scheme", scheme,
            "-configuration", configuration,
            "-destination", "platform=macOS",
            action
        ])

        return arguments
    }

    private static func parseBuildSettings(_ output: String) -> [String: String] {
        var settings: [String: String] = [:]

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !value.isEmpty else { continue }

            settings[key] = value
        }

        return settings
    }

    private static func findBuildProduct(from settings: [String: String]) -> URL? {
        let fileManager = FileManager.default
        let directoryKeys = ["TARGET_BUILD_DIR", "BUILT_PRODUCTS_DIR", "CONFIGURATION_BUILD_DIR"]
        let productKeys = ["FULL_PRODUCT_NAME", "WRAPPER_NAME", "EXECUTABLE_PATH", "EXECUTABLE_NAME"]

        for directoryKey in directoryKeys {
            guard let directory = settings[directoryKey] else { continue }

            for productKey in productKeys {
                guard let product = settings[productKey] else { continue }

                let candidate: URL
                if product.hasPrefix("/") {
                    candidate = URL(fileURLWithPath: product)
                } else {
                    candidate = URL(fileURLWithPath: directory)
                        .appendingPathComponent(product)
                }

                if fileManager.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        return nil
    }

    private static func failureMessage(from result: BuildResult) -> String {
        let combinedOutput = [result.stderr, result.stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard !combinedOutput.isEmpty else {
            return "xcodebuild failed with exit code \(result.terminationStatus)"
        }

        let diagnosticLines = combinedOutput
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                line.contains(": error:")
                    || line.contains("error:")
                    || line.contains("No such file")
                    || line.contains("does not exist")
                    || line.contains("scheme")
            }

        if !diagnosticLines.isEmpty {
            return diagnosticLines.joined(separator: "\n")
        }

        return combinedOutput
    }
}
