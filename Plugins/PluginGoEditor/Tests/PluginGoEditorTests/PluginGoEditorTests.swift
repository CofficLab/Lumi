import Foundation
import GoEditorCore
import Testing
@testable import PluginGoEditor

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

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("GoEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

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

@Test func goIssueFileResolverKeepsFileURLsAndExpandsLocalPaths() {
    let projectRoot = "/tmp/project"

    #expect(GoIssueFileResolver.url(for: "file:///tmp/project/main.go", projectRoot: projectRoot).path == "/tmp/project/main.go")
    #expect(GoIssueFileResolver.url(for: "file:///tmp/project/main with space.go", projectRoot: projectRoot).path == "/tmp/project/main with space.go")
    #expect(GoIssueFileResolver.url(for: "~/main.go", projectRoot: projectRoot).path == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("main.go").path)
    #expect(GoIssueFileResolver.url(for: "cmd/app/main.go", projectRoot: projectRoot).path == "/tmp/project/cmd/app/main.go")
}
