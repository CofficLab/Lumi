import Foundation

public extension LumiPreviewFacade {
/// 增量编译器：重编译单个文件，并将产物链接成可由宿主进程加载的 dylib。
final class IncrementalCompiler: Sendable {
    /// 创建增量编译器。
    public init() {}

    /// 用已提取的编译命令编译单个文件，返回 `.o` 路径。
    ///
    /// - Parameters:
    ///   - fileURL: 要重新编译的 Swift 文件。
    ///   - compileCommand: 从构建日志中提取的 `swift-frontend` 命令。
    /// - Returns: 编译得到的 object file 路径。
    public func compile(fileURL: URL, compileCommand: String) async throws -> URL {
        try await Task.detached {
            let outputURL = Self.outputURL(for: fileURL, compileCommand: compileCommand)
            let command = Self.command(
                compileCommand,
                outputURL: outputURL,
                shouldAppendOutput: !Self.containsOutputArgument(compileCommand)
            )
            let result = try Self.run(command)

            guard result.terminationStatus == 0 else {
                throw PreviewError.compilationFailed(message: Self.failureMessage(from: result))
            }

            guard FileManager.default.fileExists(atPath: outputURL.path) else {
                throw PreviewError.buildProductNotFound
            }

            return outputURL
        }.value
    }

    /// 将单文件编译得到的 `.o` 链接为 `.dylib`。
    ///
    /// - Parameter objectFileURL: `compile(fileURL:compileCommand:)` 返回的 object file。
    /// - Returns: 链接得到的 dylib 路径。
    public func link(objectFileURL: URL) async throws -> URL {
        try await Task.detached {
            let dylibURL = objectFileURL
                .deletingPathExtension()
                .appendingPathExtension("dylib")
            let command = "/usr/bin/env swiftc -emit-library \(Self.shellQuoted(objectFileURL.path)) -o \(Self.shellQuoted(dylibURL.path))"
            let result = try Self.run(command)

            guard result.terminationStatus == 0 else {
                throw PreviewError.compilationFailed(message: Self.failureMessage(from: result))
            }

            guard FileManager.default.fileExists(atPath: dylibURL.path) else {
                throw PreviewError.buildProductNotFound
            }

            return dylibURL
        }.value
    }

    /// 将一组 Swift 源文件直接编译为可由宿主进程加载的 `.dylib`。
    ///
    /// 多文件 entry 用于保留 Swift 文件级别的访问控制语义，避免把 target
    /// 源码拼成单个临时文件后破坏 `private` 声明作用域。
    func compileLibrary(
        sourceURLs: [URL],
        dylibURL: URL,
        compilerArguments: [String] = [],
        moduleName: String? = nil
    ) async throws -> URL {
        try await Task.detached {
            let sourceArguments = sourceURLs
                .map { Self.shellQuoted($0.path) }
                .joined(separator: " ")
            let extraArguments = Self.compilerArguments(
                compilerArguments,
                replacingModuleNameWith: moduleName
            )
                .map(Self.shellQuoted)
                .joined(separator: " ")
            let command = [
                "/usr/bin/env swiftc -emit-library",
                extraArguments,
                sourceArguments,
                "-o \(Self.shellQuoted(dylibURL.path))"
            ]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let result = try Self.run(command)

            guard result.terminationStatus == 0 else {
                throw PreviewError.compilationFailed(message: Self.failureMessage(from: result))
            }

            guard FileManager.default.fileExists(atPath: dylibURL.path) else {
                throw PreviewError.buildProductNotFound
            }

            return dylibURL
        }.value
    }

    private static func compilerArguments(
        _ arguments: [String],
        replacingModuleNameWith moduleName: String?
    ) -> [String] {
        guard let moduleName else {
            return arguments
        }

        var filtered: [String] = []
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            if argument == "-module-name" {
                _ = iterator.next()
                continue
            }
            if argument.hasPrefix("-module-name=") {
                continue
            }
            filtered.append(argument)
        }

        filtered.append(contentsOf: ["-module-name", moduleName])
        return filtered
    }

    /// 对 dylib 执行 ad-hoc codesign，满足 macOS 动态加载的签名要求。
    ///
    /// - Parameter dylibURL: 需要签名的 dylib 路径。
    public func codesign(dylibURL: URL) async throws {
        try await Task.detached {
            let command = "/usr/bin/codesign --force --sign - \(Self.shellQuoted(dylibURL.path))"
            let result = try Self.run(command)

            guard result.terminationStatus == 0 else {
                throw PreviewError.compilationFailed(message: Self.failureMessage(from: result))
            }
        }.value
    }

    private struct CompileResult: Sendable {
        let terminationStatus: Int32
        let stdout: String
        let stderr: String
    }

    private static func outputURL(for fileURL: URL, compileCommand: String) -> URL {
        if let explicitOutput = explicitOutputPath(in: compileCommand) {
            return URL(fileURLWithPath: explicitOutput)
        }

        return PreviewStoragePaths.makeTransientWorkDirectory(component: "incremental-compiler")
            .appendingPathComponent(fileURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("o")
    }

    private static func command(
        _ compileCommand: String,
        outputURL: URL,
        shouldAppendOutput: Bool
    ) -> String {
        guard shouldAppendOutput else {
            return compileCommand
        }

        return "\(compileCommand) -o \(shellQuoted(outputURL.path))"
    }

    private static func containsOutputArgument(_ command: String) -> Bool {
        command.contains(" -o ") || command.hasSuffix(" -o")
    }

    private static func explicitOutputPath(in command: String) -> String? {
        let pattern = /(?:^|\s)-o\s+(?:"([^"]+)"|'([^']+)'|(\S+))/
        guard let match = command.firstMatch(of: pattern) else {
            return nil
        }

        if let doubleQuoted = match.1 {
            return String(doubleQuoted)
        }
        if let singleQuoted = match.2 {
            return String(singleQuoted)
        }
        if let unquoted = match.3 {
            return String(unquoted)
        }

        return nil
    }

    private static func run(_ command: String) throws -> CompileResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

        let outputDirectory = PreviewStoragePaths.makeTransientWorkDirectory(component: "incremental-compiler-logs")
        defer { try? FileManager.default.removeItem(at: outputDirectory) }

        let stdoutURL = outputDirectory.appendingPathComponent("stdout.log")
        let stderrURL = outputDirectory.appendingPathComponent("stderr.log")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)

        guard let stdoutHandle = try? FileHandle(forWritingTo: stdoutURL),
              let stderrHandle = try? FileHandle(forWritingTo: stderrURL) else {
            throw PreviewError.compilationFailed(message: "Failed to capture incremental compiler output.")
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
            throw PreviewError.compilationFailed(
                message: "Failed to launch incremental compiler: \(error.localizedDescription)"
            )
        }

        process.waitUntilExit()

        return CompileResult(
            terminationStatus: process.terminationStatus,
            stdout: (try? String(contentsOf: stdoutURL, encoding: .utf8)) ?? "",
            stderr: (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
        )
    }

    private static func failureMessage(from result: CompileResult) -> String {
        let combinedOutput = [result.stderr, result.stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard !combinedOutput.isEmpty else {
            return "incremental compile failed with exit code \(result.terminationStatus)"
        }

        return combinedOutput
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

}
