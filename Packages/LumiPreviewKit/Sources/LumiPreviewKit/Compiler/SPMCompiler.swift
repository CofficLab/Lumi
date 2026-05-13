import Foundation

public extension LumiPreviewPackage {
/// SPM 编译器：使用 swift build 编译 SPM Package 中的预览。
final class SPMCompiler: Sendable {
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

    /// Returns compiler search arguments for modules produced by `swift build`.
    public func previewCompilerArguments(packageDirectory: URL, targetName: String? = nil) -> [String] {
        let buildDirectory = packageDirectory.appendingPathComponent(".build", isDirectory: true)
        let debugDirectories = Self.candidateDebugDirectories(in: buildDirectory)

        let existingDirectories = debugDirectories
            .map(\.path)
            .uniqued()
            .filter { FileManager.default.fileExists(atPath: $0) }

        var arguments: [String] = []
        for directory in existingDirectories {
            arguments.append(contentsOf: ["-I", directory, "-F", directory, "-L", directory])
            arguments.append(contentsOf: ["-Xlinker", "-rpath", "-Xlinker", directory])

            let modulesDirectory = URL(fileURLWithPath: directory)
                .appendingPathComponent("Modules", isDirectory: true)
                .path
            if FileManager.default.fileExists(atPath: modulesDirectory) {
                arguments.append(contentsOf: ["-I", modulesDirectory])
            }

            let includeDirectory = URL(fileURLWithPath: directory)
                .appendingPathComponent("include", isDirectory: true)
                .path
            if FileManager.default.fileExists(atPath: includeDirectory) {
                arguments.append(contentsOf: ["-Xcc", "-I", "-Xcc", includeDirectory])
            }
        }

        let linkInputs = Self.linkInputArguments(
            in: existingDirectories.map { URL(fileURLWithPath: $0, isDirectory: true) },
            excludingProductNames: targetName.map { [$0] } ?? []
        )
        arguments.append(contentsOf: linkInputs)
        arguments.append(contentsOf: Self.packageLinkedLibraryArguments(packageDirectory: packageDirectory))

        if !linkInputs.isEmpty {
            fputs("[SPMCompiler] previewCompilerArguments found \(linkInputs.count) .o link inputs for \(packageDirectory.lastPathComponent)\n", stderr)
        } else {
            fputs("[SPMCompiler] previewCompilerArguments found NO .o link inputs for \(packageDirectory.lastPathComponent), directories: \(existingDirectories)\n", stderr)
        }

        return arguments
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

    private static func linkInputArguments(
        in directories: [URL],
        excludingProductNames productNames: [String]
    ) -> [String] {
        let fileManager = FileManager.default
        var inputs: [String] = []

        for directory in directories {
            // .o files in SPM builds are inside TargetName.build/ subdirectories,
            // so we need to search recursively.
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let entry as URL in enumerator where entry.pathExtension == "o" {
                guard isLinkInput(entry, excludingProductNames: productNames) else { continue }
                inputs.append(entry.path)
            }
        }

        return inputs.sorted().uniqued()
    }

    private static func isLinkInput(_ url: URL, excludingProductNames productNames: [String]) -> Bool {
        let fileName = url.lastPathComponent
        let baseName = url.deletingPathExtension().lastPathComponent
        guard url.pathExtension == "o" || url.pathExtension == "a" else {
            return false
        }

        for productName in productNames where !productName.isEmpty {
            if fileName == "\(productName).o"
                || fileName == "lib\(productName).a"
                || baseName == productName {
                return false
            }
        }

        return true
    }

    private static func packageLinkedLibraryArguments(packageDirectory: URL) -> [String] {
        packageManifestURLs(packageDirectory: packageDirectory)
            .flatMap(packageLinkedLibraries(in:))
            .uniqued()
            .map { "-l\($0)" }
    }

    private static func packageManifestURLs(packageDirectory: URL) -> [URL] {
        var manifests = [packageDirectory.appendingPathComponent("Package.swift")]
        let checkoutsDirectory = packageDirectory
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("checkouts", isDirectory: true)

        if let checkouts = try? FileManager.default.contentsOfDirectory(
            at: checkoutsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            manifests.append(contentsOf: checkouts.map { $0.appendingPathComponent("Package.swift") })
        }

        return manifests
    }

    private static func packageLinkedLibraries(in packageManifest: URL) -> [String] {
        guard let source = try? String(contentsOf: packageManifest, encoding: .utf8) else {
            return []
        }
        return linkedLibraries(in: source)
    }

    private static func linkedLibraries(in packageManifest: String) -> [String] {
        let pattern = /\.linkedLibrary\(\s*"([^"]+)"/
        return packageManifest
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> String? in
                let sourceLine = String(line)
                guard let match = sourceLine.firstMatch(of: pattern) else { return nil }
                if sourceLine.contains(".when(platforms:")
                    && !sourceLine.contains(".macOS")
                    && !sourceLine.contains(".macos") {
                    return nil
                }
                return String(match.1)
            }
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

}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in self where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}

