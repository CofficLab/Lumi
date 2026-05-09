// ShellKit - A modern async Process execution library
// Provides safe, non-blocking shell command execution with streaming support

/// Shell command execution result
public struct ShellResult: Sendable {
    /// Process exit code (0 for success)
    public let exitCode: Int32

    /// Standard output content
    public let stdout: String

    /// Standard error content
    public let stderr: String

    /// Whether the command succeeded (exit code 0)
    public var isSuccess: Bool {
        exitCode == 0
    }

    /// Execution duration in seconds
    public let duration: TimeInterval?

    /// Creates a new ShellResult
    public init(
        exitCode: Int32,
        stdout: String,
        stderr: String,
        duration: TimeInterval? = nil
    ) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.duration = duration
    }
}

/// Shell command execution options
public struct ShellOptions: Sendable {
    /// Working directory for the command
    public let workingDirectory: String?

    /// Environment variables (merged with current process environment)
    public let environment: [String: String]

    /// Timeout in seconds (nil = no timeout)
    public let timeout: TimeInterval?

    /// Quality of service for background execution
    public let qos: DispatchQoS.QoSClass

    /// Whether to throw on non-zero exit code
    public let throwsOnError: Bool

    /// Creates new ShellOptions
    public init(
        workingDirectory: String? = nil,
        environment: [String: String] = [:],
        timeout: TimeInterval? = nil,
        qos: DispatchQoS.QoSClass = .userInitiated,
        throwsOnError: Bool = true
    ) {
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.timeout = timeout
        self.qos = qos
        self.throwsOnError = throwsOnError
    }

    /// Default options
    public static let defaultOptions = ShellOptions()
}

/// Shell execution error
public enum ShellError: LocalizedError, Sendable {
    /// Command execution failed with non-zero exit code
    case commandFailed(exitCode: Int32, stdout: String, stderr: String)

    /// Command timed out
    case timeout(command: String, seconds: TimeInterval)

    /// Process failed to start
    case launchFailed(command: String, reason: String)

    /// Command was cancelled
    case cancelled(command: String)

    /// Output decoding failed
    case decodingError(command: String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let exitCode, let stdout, let stderr):
            let output = stderr.isEmpty ? stdout : stderr
            return "Command failed (exit code \(exitCode)): \(output)"
        case .timeout(let command, let seconds):
            return "Command '\(command)' timed out after \(seconds)s"
        case .launchFailed(let command, let reason):
            return "Failed to launch '\(command)': \(reason)"
        case .cancelled(let command):
            return "Command '\(command)' was cancelled"
        case .decodingError(let command):
            return "Failed to decode output from '\(command)'"
        }
    }
}