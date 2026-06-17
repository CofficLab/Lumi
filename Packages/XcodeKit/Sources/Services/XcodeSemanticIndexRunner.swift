import Foundation
import os

enum XcodeSemanticIndexRunner {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "xcode.semantic-index")
    private static let fallbackFailureReason = "Unable to build semantic index"

    struct Request: Sendable, Equatable {
        let workspaceURL: URL
        let scheme: String
        let configuration: String
        let destinationQuery: String
        let storeDirectory: URL
        let derivedDataDirectory: URL
        let xcodeBuildServerPath: String
        let buildRoot: String?
    }

    static func compileDatabaseURL(in storeDirectory: URL) -> URL {
        storeDirectory.appendingPathComponent(".compile", isDirectory: false)
    }

    static func isCompileDatabaseFresh(
        compileDatabaseURL: URL,
        buildServerJSONURL: URL
    ) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: compileDatabaseURL.path),
              fileManager.fileExists(atPath: buildServerJSONURL.path) else {
            return false
        }
        guard let compileAttributes = try? fileManager.attributesOfItem(atPath: compileDatabaseURL.path),
              let buildServerAttributes = try? fileManager.attributesOfItem(atPath: buildServerJSONURL.path),
              let compileModified = compileAttributes[.modificationDate] as? Date,
              let buildServerModified = buildServerAttributes[.modificationDate] as? Date else {
            return false
        }
        return compileModified >= buildServerModified
    }

    static func isCompileDatabaseValid(
        manifest: IndexManifest?,
        compileDatabaseURL: URL,
        scheme: String,
        configuration: String,
        destination: String,
        inputs: IndexManifest.InputFingerprints,
        toolchain: IndexManifest.ToolchainInfo
    ) -> Bool {
        IndexManifestValidation.isCompileDatabaseValid(
            manifest: manifest,
            compileDatabaseURL: compileDatabaseURL,
            scheme: scheme,
            configuration: configuration,
            destination: destination,
            inputs: inputs,
            toolchain: toolchain
        )
    }

    static func syncCompileDatabaseFromDerivedData(_ request: Request) async -> Bool {
        guard isBuildRootUnderDerivedData(request) else {
            return false
        }

        guard let buildRoot = request.buildRoot?.trimmingCharacters(in: .whitespacesAndNewlines),
              !buildRoot.isEmpty else {
            return false
        }

        let compileURL = compileDatabaseURL(in: request.storeDirectory)
        let synced = await runCommand(
            executablePath: request.xcodeBuildServerPath,
            arguments: ["parse", "-s", buildRoot, "-o", compileURL.path],
            workingDirectory: request.storeDirectory
        )
        guard synced else { return false }
        return await CompileDatabaseValidator.validateForPromotion(at: compileURL, scheme: request.scheme) == nil
    }

    static func buildAndParseCompileDatabase(_ request: Request) async -> String? {
        let compileURL = compileDatabaseURL(in: request.storeDirectory)
        let logURL = request.storeDirectory.appendingPathComponent("semantic-index-build.log")

        let buildSucceeded = await runXcodeBuildCapturingLog(request: request, logURL: logURL)
        guard buildSucceeded else {
            logger.error("Semantic index xcodebuild failed for scheme \(request.scheme, privacy: .public)")
            return failureReasonFromBuildLog(logURL) ?? "xcodebuild failed"
        }

        // Try parsing from the derived-data build root first (binary xcactivitylog extraction).
        //
        // Write to a temp file and only promote it to `.compile` once validated: on some Xcode
        // versions the xcactivitylog extractor silently yields an *empty* database (exit 0, zero
        // entries). Parsing straight into `.compile` would clobber a good database with that empty
        // result, so we keep `.compile` untouched until the text-log fallback (below) succeeds.
        if let buildRoot = discoverBuildRoot(in: request.derivedDataDirectory) {
            let stagingURL = request.storeDirectory.appendingPathComponent(".compile.parse-s.tmp")
            let derivedParse = await runCommand(
                executablePath: request.xcodeBuildServerPath,
                arguments: ["parse", "-s", buildRoot, "-o", stagingURL.path],
                workingDirectory: request.storeDirectory
            )
            if derivedParse, await CompileDatabaseValidator.validateForPromotion(at: stagingURL, scheme: request.scheme) == nil {
                try? FileManager.default.removeItem(at: compileURL)
                if (try? FileManager.default.moveItem(at: stagingURL, to: compileURL)) != nil {
                    return nil
                }
            } else if derivedParse {
                logger.error("Semantic index parse(-s) produced invalid compile DB; falling back to log parse")
            }
            try? FileManager.default.removeItem(at: stagingURL)
        }

        let parseResult = await runCommandCapturingOutput(
            executablePath: request.xcodeBuildServerPath,
            arguments: ["parse", "-o", compileURL.path, logURL.path],
            workingDirectory: request.storeDirectory
        )
        if parseResult.succeeded, let issue = await CompileDatabaseValidator.validateForPromotion(at: compileURL, scheme: request.scheme) {
            return issue
        }

        if parseResult.succeeded {
            return nil
        }
        let parseMessage = normalizedFailureReason(parseResult.output)
        return parseMessage.isEmpty ? "xcode-build-server parse failed" : parseMessage
    }

    static func discoverBuildRoot(in derivedDataDirectory: URL) -> String? {
        let fileManager = FileManager.default
        // Xcode can place Build/Logs directly under -derivedDataPath.
        let directBuildPath = derivedDataDirectory.appendingPathComponent("Build").path
        let directLogsPath = derivedDataDirectory.appendingPathComponent("Logs").path
        if fileManager.fileExists(atPath: directBuildPath) || fileManager.fileExists(atPath: directLogsPath) {
            return derivedDataDirectory.path
        }

        guard let entries = try? fileManager.contentsOfDirectory(
            at: derivedDataDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let candidates = entries.filter { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return false
            }
            let buildPath = url.appendingPathComponent("Build").path
            let logsPath = url.appendingPathComponent("Logs").path
            return fileManager.fileExists(atPath: buildPath) || fileManager.fileExists(atPath: logsPath)
        }

        return candidates.max { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate < rhsDate
        }?.path
    }

    static func isBuildRootUnderDerivedData(_ request: Request) -> Bool {
        guard let buildRoot = request.buildRoot?.trimmingCharacters(in: .whitespacesAndNewlines),
              !buildRoot.isEmpty else {
            return false
        }

        let managedPrefix = request.derivedDataDirectory.standardizedFileURL.path
        let normalizedBuildRoot = URL(fileURLWithPath: buildRoot).standardizedFileURL.path
        return normalizedBuildRoot == managedPrefix || normalizedBuildRoot.hasPrefix(managedPrefix + "/")
    }

    /// Builds the `xcodebuild` arguments for a semantic-index build.
    ///
    /// A `clean build` is used on purpose: `xcode-build-server parse` reconstructs `.compile` from
    /// the build's xcactivitylog, which only contains the targets that were actually (re)compiled.
    /// On an already-built DerivedData an incremental build would log just a few targets and produce
    /// a partial compile database, so files in unbuilt targets would fall back and report spurious
    /// "No such module" errors. Cleaning first guarantees every target is compiled and logged.
    static func xcodebuildArguments(for request: Request) -> [String] {
        var arguments: [String] = []
        if request.workspaceURL.pathExtension == "xcworkspace" {
            arguments.append(contentsOf: ["-workspace", request.workspaceURL.path])
        } else {
            arguments.append(contentsOf: ["-project", request.workspaceURL.path])
        }
        arguments.append(contentsOf: [
            "-scheme", request.scheme,
            "-configuration", request.configuration,
            "-destination", request.destinationQuery,
            "-derivedDataPath", request.derivedDataDirectory.path,
            "clean",
            "build",
        ])
        return arguments
    }

    private static func runXcodeBuildCapturingLog(request: Request, logURL: URL) async -> Bool {
        let arguments = xcodebuildArguments(for: request)

        return await runCommand(
            executablePath: "/usr/bin/xcodebuild",
            arguments: arguments,
            workingDirectory: request.storeDirectory,
            combinedLogURL: logURL
        )
    }

    private static func runCommand(
        executablePath: String,
        arguments: [String],
        workingDirectory: URL,
        combinedLogURL: URL? = nil
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: workingDirectory.path) {
                    do {
                        try fileManager.createDirectory(
                            at: workingDirectory,
                            withIntermediateDirectories: true
                        )
                    } catch {
                        logger.error("Failed to create working directory \(workingDirectory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        continuation.resume(returning: false)
                        return
                    }
                }

                let process = Process()
                process.executableURL = URL(filePath: executablePath)
                process.arguments = arguments
                process.currentDirectoryURL = workingDirectory
                if #available(macOS 13.0, *) {
                    process.qualityOfService = .utility
                }
                if executablePath.hasSuffix("xcodebuild") {
                    var environment = ProcessInfo.processInfo.environment
                    environment["IDEBuildOperationMaxNumberOfConcurrentCompileTasks"] = "4"
                    process.environment = environment
                }

                var outputHandle: FileHandle?
                var errorHandle: FileHandle?

                if let combinedLogURL {
                    fileManager.createFile(atPath: combinedLogURL.path, contents: nil)
                    guard let stdoutHandle = try? FileHandle(forWritingTo: combinedLogURL),
                          let stderrHandle = try? FileHandle(forWritingTo: combinedLogURL) else {
                        continuation.resume(returning: false)
                        return
                    }
                    stdoutHandle.seekToEndOfFile()
                    stderrHandle.seekToEndOfFile()
                    outputHandle = stdoutHandle
                    errorHandle = stderrHandle
                    process.standardOutput = stdoutHandle
                    process.standardError = stderrHandle
                } else {
                    process.standardOutput = FileHandle.nullDevice
                    process.standardError = FileHandle.nullDevice
                }

                defer {
                    try? outputHandle?.close()
                    try? errorHandle?.close()
                }

                do {
                    try process.run()
                } catch {
                    logger.error("Failed to launch \(executablePath, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: false)
                    return
                }

                Task { @MainActor in
                    SemanticIndexJobController.shared.registerProcess(process)
                }

                process.waitUntilExit()
                Task { @MainActor in
                    SemanticIndexJobController.shared.clearProcessRegistration()
                }
                continuation.resume(returning: process.terminationStatus == 0)
            }
        }
    }

    static func runCommandCapturingOutput(
        executablePath: String,
        arguments: [String],
        workingDirectory: URL
    ) async -> (succeeded: Bool, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: workingDirectory.path) {
                    do {
                        try fileManager.createDirectory(
                            at: workingDirectory,
                            withIntermediateDirectories: true
                        )
                    } catch {
                        logger.error("Failed to create working directory \(workingDirectory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        continuation.resume(returning: (false, ""))
                        return
                    }
                }

                let process = Process()
                process.executableURL = URL(filePath: executablePath)
                process.arguments = arguments
                process.currentDirectoryURL = workingDirectory

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                } catch {
                    logger.error("Failed to launch \(executablePath, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: (false, ""))
                    return
                }

                // Drain the pipe *before* waiting for exit. The kernel pipe buffer is only ~64KB, so a
                // verbose child (e.g. `xcode-build-server parse` on a large project emits hundreds of KB
                // to stderr) fills it, blocks on write, and never exits — deadlocking `waitUntilExit()`.
                // `readDataToEndOfFile()` keeps emptying the buffer until the child closes the pipe on exit.
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: (process.terminationStatus == 0, output))
            }
        }
    }

    static func failureReasonFromBuildLog(_ logURL: URL) -> String? {
        guard let content = try? String(contentsOf: logURL, encoding: .utf8) else {
            return nil
        }
        return normalizedFailureReason(content)
    }

    static func normalizedFailureReason(_ raw: String) -> String {
        let lines = raw
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return fallbackFailureReason
        }

        let important = lines.reversed().first { line in
            line.localizedCaseInsensitiveContains("error:") ||
                line.localizedCaseInsensitiveContains("failed") ||
                line.localizedCaseInsensitiveContains("no such module") ||
                line.localizedCaseInsensitiveContains("command")
        } ?? lines.last!
        return important
    }

    static func compileDatabaseHasEntries(at compileURL: URL) -> Bool {
        guard let data = try? Data(contentsOf: compileURL),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return false
        }
        return !array.isEmpty
    }

    static func validateCompileDatabase(at compileURL: URL, scheme: String) -> String? {
        guard let data = try? Data(contentsOf: compileURL),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !array.isEmpty else {
            return "semantic compile database is empty"
        }

        let includesSchemeModule = array.contains { entry in
            let moduleName = (entry["module_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if moduleName == scheme { return true }
            let command = (entry["command"] as? String) ?? ""
            return command.contains("-module-name \(scheme) ")
        }
        guard includesSchemeModule else {
            let moduleNames = Array(Set(array.compactMap { ($0["module_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }))
                .filter { !$0.isEmpty }
                .sorted()
            let listed = moduleNames.prefix(5).joined(separator: ", ")
            return listed.isEmpty
                ? "semantic compile database does not include scheme module '\(scheme)'"
                : "semantic compile database missing module '\(scheme)' (found: \(listed))"
        }
        return nil
    }
}
