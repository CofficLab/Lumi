import Foundation

public extension LumiPreviewFacade {
    struct SyntaxCheckIssue: Sendable, Equatable {
        public let message: String

        public init(message: String) {
            self.message = message
        }
    }

    enum SyntaxCheckResult: Sendable, Equatable {
        case valid
        case invalid([SyntaxCheckIssue])
    }

    protocol CommandRunning: Sendable {
        func run(_ command: [String]) async throws -> CommandResult
    }

    struct CommandResult: Sendable, Equatable {
        public let exitCode: Int32
        public let standardOutput: String
        public let standardError: String

        public init(exitCode: Int32, standardOutput: String = "", standardError: String = "") {
            self.exitCode = exitCode
            self.standardOutput = standardOutput
            self.standardError = standardError
        }
    }

    struct ProcessCommandRunner: CommandRunning {
        public init() {}

        public func run(_ command: [String]) async throws -> CommandResult {
            guard let executable = command.first else {
                return CommandResult(exitCode: 127, standardError: "Missing executable.")
            }

            return try await Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = Array(command.dropFirst())

                let outputDirectory = PreviewStoragePaths.makeTransientWorkDirectory(component: "syntax-checker")
                defer { try? FileManager.default.removeItem(at: outputDirectory) }

                let stdoutURL = outputDirectory.appendingPathComponent("stdout.log")
                let stderrURL = outputDirectory.appendingPathComponent("stderr.log")
                FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
                FileManager.default.createFile(atPath: stderrURL.path, contents: nil)

                let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
                let stderrHandle = try FileHandle(forWritingTo: stderrURL)
                process.standardOutput = stdoutHandle
                process.standardError = stderrHandle

                do {
                    try process.run()
                } catch {
                    try? stdoutHandle.close()
                    try? stderrHandle.close()
                    throw error
                }

                process.waitUntilExit()
                try? stdoutHandle.close()
                try? stderrHandle.close()

                return CommandResult(
                    exitCode: process.terminationStatus,
                    standardOutput: (try? String(contentsOf: stdoutURL, encoding: .utf8)) ?? "",
                    standardError: (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
                )
            }.value
        }
    }

    /// Fast Swift syntax preflight used to avoid expensive preview builds.
    struct SyntaxChecker: Sendable {
        private let swiftcPath: String
        private let runner: any CommandRunning

        public init(
            swiftcPath: String = "/usr/bin/swiftc",
            runner: any CommandRunning = ProcessCommandRunner()
        ) {
            self.swiftcPath = swiftcPath
            self.runner = runner
        }

        public func check(fileURL: URL, extraArguments: [String] = []) async -> SyntaxCheckResult {
            var command = [swiftcPath, "-parse"]
            command.append(contentsOf: extraArguments)
            command.append(fileURL.path)

            do {
                let result = try await runner.run(command)
                guard result.exitCode == 0 else {
                    let diagnostics = result.standardError.isEmpty ? result.standardOutput : result.standardError
                    return .invalid(Self.issues(from: diagnostics))
                }
                return .valid
            } catch {
                return .invalid([SyntaxCheckIssue(message: error.localizedDescription)])
            }
        }

        static func issues(from diagnostics: String) -> [SyntaxCheckIssue] {
            let messages = diagnostics
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { SyntaxCheckIssue(message: String($0)) }
            return messages.isEmpty ? [SyntaxCheckIssue(message: "Unknown syntax error.")] : messages
        }
    }
}
