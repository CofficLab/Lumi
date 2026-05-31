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
