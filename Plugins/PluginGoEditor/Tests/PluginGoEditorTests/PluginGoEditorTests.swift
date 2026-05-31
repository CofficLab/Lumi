import Foundation
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

@Test func goIssueFileResolverKeepsFileURLsAndExpandsLocalPaths() {
    let projectRoot = "/tmp/project"

    #expect(GoIssueFileResolver.url(for: "file:///tmp/project/main.go", projectRoot: projectRoot).path == "/tmp/project/main.go")
    #expect(GoIssueFileResolver.url(for: "file:///tmp/project/main with space.go", projectRoot: projectRoot).path == "/tmp/project/main with space.go")
    #expect(GoIssueFileResolver.url(for: "~/main.go", projectRoot: projectRoot).path == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("main.go").path)
    #expect(GoIssueFileResolver.url(for: "cmd/app/main.go", projectRoot: projectRoot).path == "/tmp/project/cmd/app/main.go")
}
