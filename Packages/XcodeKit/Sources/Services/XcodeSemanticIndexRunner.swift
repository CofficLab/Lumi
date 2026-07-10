import Foundation
import os
import SuperLogKit

enum XcodeSemanticIndexRunner: SuperLog {
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
            logger.error("\(Self.t)Semantic index xcodebuild failed for scheme \(request.scheme, privacy: .public)")
            return failureReasonFromBuildLog(logURL) ?? "xcodebuild failed"
        }

        // Parse the freshly built (incremental) result into a staging file, then **merge** it onto the
        // existing `.compile`. The build is incremental, so the parsed result only contains the files
        // that were recompiled; merging preserves the entries for skipped files (and the scheme
        // module, if its target wasn't rebuilt) instead of clobbering them.
        //
        // We still stage before promoting: on some Xcode versions the xcactivitylog extractor silently
        // yields an *empty* database (exit 0, zero entries). `compileDatabaseHasEntries` guards against
        // merging that empty result on top of a good database.
        let stagingURL = request.storeDirectory.appendingPathComponent(".compile.parse-s.tmp")
        defer { try? FileManager.default.removeItem(at: stagingURL) }

        let parsedFromDerivedData: Bool
        if let buildRoot = discoverBuildRoot(in: request.derivedDataDirectory) {
            parsedFromDerivedData = await runCommand(
                executablePath: request.xcodeBuildServerPath,
                arguments: ["parse", "-s", buildRoot, "-o", stagingURL.path],
                workingDirectory: request.storeDirectory
            )
        } else {
            parsedFromDerivedData = false
        }

        var stagingURLToUse = stagingURL
        if !parsedFromDerivedData {
            // Fall back to parsing the text build log into the staging file.
            let parseResult = await runCommandCapturingOutput(
                executablePath: request.xcodeBuildServerPath,
                arguments: ["parse", "-o", stagingURL.path, logURL.path],
                workingDirectory: request.storeDirectory
            )
            guard parseResult.succeeded else {
                let parseMessage = normalizedFailureReason(parseResult.output)
                return parseMessage.isEmpty ? "xcode-build-server parse failed" : parseMessage
            }
            stagingURLToUse = stagingURL
        } else if !compileDatabaseHasEntries(at: stagingURLToUse) {
            // The derived-data parse silently produced an empty database — fall back to the text log.
            logger.error("\(Self.t)Semantic index parse(-s) produced empty compile DB; falling back to log parse")
            let parseResult = await runCommandCapturingOutput(
                executablePath: request.xcodeBuildServerPath,
                arguments: ["parse", "-o", stagingURL.path, logURL.path],
                workingDirectory: request.storeDirectory
            )
            guard parseResult.succeeded else {
                let parseMessage = normalizedFailureReason(parseResult.output)
                return parseMessage.isEmpty ? "xcode-build-server parse failed" : parseMessage
            }
        }

        guard compileDatabaseHasEntries(at: stagingURLToUse) else {
            return "semantic compile database is empty after parse"
        }

        // Merge the staged (incremental) result into the existing `.compile`. On the first build there
        // is no existing database, so this promotes the staged result as-is.
        let existingURL = request.storeDirectory.appendingPathComponent(".compile.existing.tmp")
        if FileManager.default.fileExists(atPath: compileURL.path) {
            try? FileManager.default.removeItem(at: existingURL)
            try? FileManager.default.copyItem(at: compileURL, to: existingURL)
        } else {
            try? FileManager.default.removeItem(at: existingURL)
        }
        defer { try? FileManager.default.removeItem(at: existingURL) }

        guard mergeCompileDatabase(new: stagingURLToUse, existing: existingURL, into: compileURL) else {
            return "semantic compile database merge failed"
        }

        // Validate the *merged* database for the scheme module: it must include the scheme's own
        // target, whether provided by this incremental parse or retained from a previous full build.
        if let issue = await CompileDatabaseValidator.validateForPromotion(at: compileURL, scheme: request.scheme) {
            return issue
        }

        return nil
    }

    /// Merges a freshly parsed (incremental, possibly partial) compile database on top of an
    /// existing one, writing the result to `destinationURL`.
    ///
    /// Each entry in a `.compile` database describes how a single source file is compiled, keyed by
    /// its `directory` + `file`. An incremental `xcodebuild build` only re-logs the files that were
    /// actually recompiled, so the freshly parsed database omits every file in targets Xcode skipped.
    /// Merging — rather than replacing — keeps those skipped files' (still-valid) entries while
    /// overwriting the entries for files that were just rebuilt.
    ///
    /// - If `existingURL` is missing or unreadable, the new database is promoted as-is (first build).
    /// - Returns `true` if `destinationURL` was written successfully.
    @discardableResult
    static func mergeCompileDatabase(new newURL: URL, existing existingURL: URL, into destinationURL: URL) -> Bool {
        let fileManager = FileManager.default

        guard let newData = try? Data(contentsOf: newURL),
              let newEntries = (try? JSONSerialization.jsonObject(with: newData)) as? [[String: Any]],
              !newEntries.isEmpty else {
            // Nothing valid parsed; leave whatever exists untouched.
            return false
        }

        // No existing database to merge into → promote the new (complete-on-first-build) one.
        guard fileManager.fileExists(atPath: existingURL.path),
              let existingData = try? Data(contentsOf: existingURL),
              let existingEntries = (try? JSONSerialization.jsonObject(with: existingData)) as? [[String: Any]] else {
            try? fileManager.removeItem(at: destinationURL)
            do {
                try fileManager.moveItem(at: newURL, to: destinationURL)
                return true
            } catch {
                Self.logger.error("\(Self.t)Compile DB promote failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }

        // Key entries by their source-file identity (normalized directory + file).
        var merged: [String: [String: Any]] = [:]
        for entry in existingEntries {
            if let key = compileEntryKey(for: entry) { merged[key] = entry }
        }
        for entry in newEntries {
            // Newly built files overwrite stale entries; previously-unseen files are added.
            if let key = compileEntryKey(for: entry) { merged[key] = entry }
        }

        let combined = Array(merged.values)
        guard let data = try? JSONSerialization.data(withJSONObject: combined, options: [.prettyPrinted]) else {
            Self.logger.error("\(Self.t)Compile DB merge serialization failed")
            return false
        }

        do {
            try data.write(to: destinationURL, options: .atomic)
            try? fileManager.removeItem(at: newURL)
            return true
        } catch {
            Self.logger.error("\(Self.t)Compile DB merge write failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Stable identity for a `.compile` entry: the source file it compiles.
    /// Falls back to `nil` for malformed entries (which are then dropped, since they can't be keyed).
    private static func compileEntryKey(for entry: [String: Any]) -> String? {
        let directory = (entry["directory"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let file = (entry["file"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !file.isEmpty else { return nil }
        let normalizedDirectory = (directory as NSString).standardizingPath
        return "\(normalizedDirectory)/\(file)"
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
    /// An **incremental** build is used (no `clean`): `xcode-build-server parse` reconstructs `.compile`
    /// from the build's xcactivitylog, which only contains the targets that were actually (re)compiled.
    /// Previously a `clean` guaranteed every target was compiled and logged, at the cost of a full
    /// rebuild — and a very high, sustained CPU spike — on every re-index.
    ///
    /// With incremental builds the freshly parsed database is *partial* (only recompiled targets),
    /// so it is **merged** into the existing `.compile` by `mergeCompileDatabase(new:existing:)`:
    /// entries for files that were just rebuilt overwrite their stale counterparts, while entries for
    /// files that were *not* rebuilt (in targets Xcode skipped) are preserved unchanged. This keeps
    /// the database complete across incremental re-indexes without ever paying for a clean build.
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
                        logger.error("\(Self.t)Failed to create working directory \(workingDirectory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
                    // Capped at 2 (down from 4) to flatten the CPU spike during indexing builds.
                    // Semantic indexing is background work; trading a longer build for a lower, less
                    // noticeable CPU peak keeps the editor responsive while the index is refreshed.
                    environment["IDEBuildOperationMaxNumberOfConcurrentCompileTasks"] = "2"
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
                    logger.error("\(Self.t)Failed to launch \(executablePath, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
                        logger.error("\(Self.t)Failed to create working directory \(workingDirectory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
                    logger.error("\(Self.t)Failed to launch \(executablePath, privacy: .public): \(error.localizedDescription, privacy: .public)")
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
        } ?? lines.last ?? ""
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
