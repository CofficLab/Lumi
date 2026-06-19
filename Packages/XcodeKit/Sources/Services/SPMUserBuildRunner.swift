import Foundation

/// Executes `swift build` for SPM executable targets.
public actor SPMUserBuildRunner {

  public init() {}

  public struct Request: Sendable {
    public let packageRoot: URL
    public let executableTarget: String
    public let configuration: String

    public init(packageRoot: URL, executableTarget: String, configuration: String) {
      self.packageRoot = packageRoot
      self.executableTarget = executableTarget
      self.configuration = configuration
    }
  }

  private var currentProcess: Process?
  private var cancelRequested = false

  public var isRunning: Bool {
    currentProcess?.isRunning == true
  }

  public static func swiftBuildArguments(for request: Request, swiftPath: String) -> [String] {
    [
      swiftPath,
      "build",
      "--package-path", request.packageRoot.path,
      "--configuration", request.configuration.lowercased(),
      "--product", request.executableTarget,
    ]
  }

  public static func locateSwiftExecutable() -> String? {
    let candidates = [
      "/usr/bin/swift",
      "/Library/Developer/CommandLineTools/usr/bin/swift",
    ]
    let fileManager = FileManager.default
    for path in candidates where fileManager.isExecutableFile(atPath: path) {
      return path
    }
    return runWhich("swift")
  }

  public func build(
    request: Request,
    onOutputLine: @escaping @Sendable (String) -> Void
  ) async -> SwiftBuildRunResult {
    cancelRequested = false
    terminateRunningProcessIfNeeded()

    guard let swiftPath = Self.locateSwiftExecutable() else {
      return SwiftBuildRunResult(
        exitCode: -1,
        stderr: "swift command not found",
        wasCancelled: false
      )
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = Self.swiftBuildArguments(for: request, swiftPath: swiftPath)
    process.currentDirectoryURL = request.packageRoot

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    currentProcess = process

    let stdoutCollector = SPMBuildOutputCollector()
    let stderrCollector = SPMBuildOutputCollector()

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
    let productURL = XcodeBuildProductResolver.resolveSPMProduct(
      packageRoot: request.packageRoot,
      targetName: request.executableTarget,
      configuration: request.configuration
    )

    return SwiftBuildRunResult(
      exitCode: Int(exitCode),
      stdout: stdout,
      stderr: stderr,
      issues: parsed.issues,
      productURL: productURL,
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

  private static func runWhich(_ command: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = [command]
    let pipe = Pipe()
    process.standardOutput = pipe
    do {
      try process.run()
      process.waitUntilExit()
      guard process.terminationStatus == 0 else { return nil }
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let path = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard let path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else {
        return nil
      }
      return path
    } catch {
      return nil
    }
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

private final class SPMBuildOutputCollector: @unchecked Sendable {
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
