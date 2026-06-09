import Foundation
import GoEditorCore
import Testing
@testable import GoEditorPlugin

@Test func packageLoads() async throws {
    #expect(GoEditorPlugin.id == "GoEditor")
}

@Test func outputCollectorDrainsLargePipePayloads() async throws {
    let pipe = Pipe()
    let payload = Data(repeating: 65, count: 256 * 1024)

    async let collected = GoRunnerOutputCollector.readData(from: pipe)
    pipe.fileHandleForWriting.write(payload)
    pipe.fileHandleForWriting.closeFile()

    #expect(await collected == payload)
}

@Test func goRunnerCancelStopsRunningProcessPromptly() async throws {
    guard GoEnvResolver.goPath != nil else { return }

    let directory = try makeSlowGoTestPackage()
    defer { try? FileManager.default.removeItem(at: directory) }

    let runner = GoRunner()
    let start = Date()
    let task = Task {
        await runner.execute(
            command: "test",
            arguments: ["-run", "TestSlow", "-count=1", "-v", "."],
            workingDirectory: directory.path
        )
    }

    try await Task.sleep(nanoseconds: 100_000_000)
    await runner.cancel()
    let result = await task.value

    #expect(Date().timeIntervalSince(start) < 2)
    #expect(result.exitCode != 0)
    #expect(!result.stdout.contains("should-not-complete"))
}

@MainActor
@Test func goTestManagerCancelStopsRunningTestsPromptly() async throws {
    guard GoEnvResolver.goPath != nil else { return }

    let directory = try makeSlowGoTestPackage()
    defer { try? FileManager.default.removeItem(at: directory) }

    let manager = GoTestManager()
    let start = Date()
    let task = Task { @MainActor in
        await manager.test(workingDirectory: directory.path)
    }

    try await Task.sleep(nanoseconds: 100_000_000)
    manager.cancel()
    await task.value

    #expect(Date().timeIntervalSince(start) < 2)
    #expect(manager.state == .cancelled)
}

@Test func goIssueFileResolverKeepsFileURLsAndExpandsLocalPaths() {
    let projectRoot = "/tmp/project"

    #expect(GoIssueFileResolver.url(for: "file:///tmp/project/main.go", projectRoot: projectRoot).path == "/tmp/project/main.go")
    #expect(GoIssueFileResolver.url(for: "file:///tmp/project/main with space.go", projectRoot: projectRoot).path == "/tmp/project/main with space.go")
    #expect(GoIssueFileResolver.url(for: "~/main.go", projectRoot: projectRoot).path == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("main.go").path)
    #expect(GoIssueFileResolver.url(for: "cmd/app/main.go", projectRoot: projectRoot).path == "/tmp/project/cmd/app/main.go")
}

private func makeSlowGoTestPackage() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("GoEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    try """
    module example.com/canceltest

    go 1.21
    """.write(to: directory.appendingPathComponent("go.mod"), atomically: true, encoding: .utf8)
    try """
    package canceltest

    import (
        "fmt"
        "testing"
        "time"
    )

    func TestSlow(t *testing.T) {
        time.Sleep(5 * time.Second)
        fmt.Println("should-not-complete")
    }
    """.write(to: directory.appendingPathComponent("main_test.go"), atomically: true, encoding: .utf8)

    return directory
}
