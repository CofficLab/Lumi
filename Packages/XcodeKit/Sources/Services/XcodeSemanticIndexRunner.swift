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
        return synced && validateCompileDatabase(at: compileURL, scheme: request.scheme) == nil
    }

    static func buildAndParseCompileDatabase(_ request: Request) async -> String? {
        let compileURL = compileDatabaseURL(in: request.storeDirectory)
        let logURL = request.storeDirectory.appendingPathComponent("semantic-index-build.log")

        let buildSucceeded = await runXcodeBuildCapturingLog(request: request, logURL: logURL)
        guard buildSucceeded else {
            logger.error("Semantic index xcodebuild failed for scheme \(request.scheme, privacy: .public)")
            return failureReasonFromBuildLog(logURL) ?? "xcodebuild failed"
        }

        // Prefer parsing from derived-data build root because it is more stable than log parsing.
        if let buildRoot = discoverBuildRoot(in: request.derivedDataDirectory) {
            let derivedParse = await runCommand(
                executablePath: request.xcodeBuildServerPath,
                arguments: ["parse", "-s", buildRoot, "-o", compileURL.path],
                workingDirectory: request.storeDirectory
            )
            if derivedParse, let issue = validateCompileDatabase(at: compileURL, scheme: request.scheme) {
                logger.error("Semantic index parse(-s) produced invalid compile DB: \(issue, privacy: .public)")
            } else if derivedParse {
                return nil
            }
        }

        let parseResult = await runCommandCapturingOutput(
            executablePath: request.xcodeBuildServerPath,
            arguments: ["parse", "-o", compileURL.path, logURL.path],
            workingDirectory: request.storeDirectory
        )
        if parseResult.succeeded, let issue = validateCompileDatabase(at: compileURL, scheme: request.scheme) {
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

    private static func runXcodeBuildCapturingLog(request: Request, logURL: URL) async -> Bool {
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

                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus == 0)
            }
        }
    }

    private static func runCommandCapturingOutput(
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

                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
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
