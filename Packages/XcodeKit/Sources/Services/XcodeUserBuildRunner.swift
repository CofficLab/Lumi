import Foundation

/// Executes incremental `xcodebuild build` for user-initiated Run.
public actor XcodeUserBuildRunner {

  public init() {}

  public struct Request: Sendable {
    public let workspaceURL: URL
    public let scheme: String
    public let configuration: String
    public let destinationQuery: String
    public let derivedDataDirectory: URL
    public let workingDirectory: URL

    public init(
      workspaceURL: URL,
      scheme: String,
      configuration: String,
      destinationQuery: String,
      derivedDataDirectory: URL,
      workingDirectory: URL
    ) {
      self.workspaceURL = workspaceURL
      self.scheme = scheme
      self.configuration = configuration
      self.destinationQuery = destinationQuery
      self.derivedDataDirectory = derivedDataDirectory
      self.workingDirectory = workingDirectory
    }
  }

  private var currentProcess: Process?
  private var cancelRequested = false

  public var isRunning: Bool {
    currentProcess?.isRunning == true
  }

  public static func xcodebuildArguments(for request: Request) -> [String] {
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

  public func build(
    request: Request,
    onOutputLine: @escaping @Sendable (String) -> Void
  ) async -> SwiftBuildRunResult {
    cancelRequested = false
    terminateRunningProcessIfNeeded()

    let arguments = Self.xcodebuildArguments(for: request)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
    process.arguments = arguments
    process.currentDirectoryURL = request.workingDirectory

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    currentProcess = process

    let stdoutCollector = BuildOutputCollector()
    let stderrCollector = BuildOutputCollector()

    stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      stdoutCollector.append(data) { line in
        onOutputLine(line)
      }
    }
    stderrPipe.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      stderrCollector.append(data) { line in
        onOutputLine(line)
      }
    }

    let exitCode: Int32
    do {
      exitCode = try await Self.runAndWait(process)
    } catch {
      cleanupPipes(stdout: stdoutPipe, stderr: stderrPipe)
      currentProcess = nil
      return SwiftBuildRunResult(
        exitCode: -1,
        stderr: error.localizedDescription,
        wasCancelled: cancelRequested
      )
    }

    cleanupPipes(stdout: stdoutPipe, stderr: stderrPipe)
    currentProcess = nil

    let stdout = stdoutCollector.finalize()
    let stderr = stderrCollector.finalize()
    let parsed = XcodeBuildIssueParser.parse(stdout: stdout, stderr: stderr)

    return SwiftBuildRunResult(
      exitCode: Int(exitCode),
      stdout: stdout,
      stderr: stderr,
      issues: parsed.issues,
      wasCancelled: cancelRequested
    )
  }

  public func cancel() {
    cancelRequested = true
    terminateRunningProcessIfNeeded()
  }

  private func terminateRunningProcessIfNeeded() {
    guard let process = currentProcess, process.isRunning else { return }
    process.terminate()
  }

  private func cleanupPipes(stdout: Pipe, stderr: Pipe) {
    stdout.fileHandleForReading.readabilityHandler = nil
    stderr.fileHandleForReading.readabilityHandler = nil
    try? stdout.fileHandleForWriting.close()
    try? stderr.fileHandleForWriting.close()
  }

  private static func runAndWait(_ process: Process) async throws -> Int32 {
    try await withCheckedThrowingContinuation { continuation in
      process.terminationHandler = { terminatedProcess in
        continuation.resume(returning: terminatedProcess.terminationStatus)
      }
      do {
        try process.run()
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}

// MARK: - Output Collector

private final class BuildOutputCollector: @unchecked Sendable {
  private var buffer = ""
  private var output = ""
  private let lock = NSLock()

  func append(_ data: Data, onLine: (String) -> Void) {
    guard let chunk = String(data: data, encoding: .utf8) else { return }
    lock.lock()
    buffer += chunk
    while let newlineIndex = buffer.firstIndex(of: "\n") {
      let line = String(buffer[..<newlineIndex])
      buffer = String(buffer[buffer.index(after: newlineIndex)...])
      output += line + "\n"
      lock.unlock()
      onLine(line)
      lock.lock()
    }
    lock.unlock()
  }

  func finalize() -> String {
    lock.lock()
    defer { lock.unlock() }
    if !buffer.isEmpty {
      output += buffer
      buffer = ""
    }
    return output
  }
}
