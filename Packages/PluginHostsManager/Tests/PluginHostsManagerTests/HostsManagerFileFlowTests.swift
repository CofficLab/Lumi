import Foundation
import Testing
@testable import PluginHostsManager

@Suite("Hosts manager file flow")
@MainActor
struct HostsManagerFileFlowTests {
    @Test("loads entries, saves their serialization, and reloads the saved content")
    func loadsAndSavesThroughInjectedFileOperations() async {
        let file = StubHostsFile(content: "127.0.0.1 initial.test")
        let model = makeViewModel(file: file)

        await model.loadHosts()
        #expect(model.entries.map(\.type) == [
            .entry(ip: "127.0.0.1", domains: ["initial.test"], isEnabled: true, comment: nil),
        ])
        #expect(model.isLoading == false)
        #expect(model.errorMessage == nil)

        model.entries = [
            HostEntry(type: .groupHeader("Development")),
            HostEntry(type: .entry(ip: "127.0.0.2", domains: ["app.test"], isEnabled: true, comment: "local")),
        ]
        await model.saveHosts()

        let savedContent = "# GROUP: Development\n127.0.0.2 app.test # local\n"
        #expect(file.writes == [savedContent])
        #expect(model.entries.map(\.type) == [
            .groupHeader("Development"),
            .entry(ip: "127.0.0.2", domains: ["app.test"], isEnabled: true, comment: "local"),
        ])
        #expect(model.isLoading == false)
        #expect(model.errorMessage == nil)
    }

    @Test("surfaces read and write failures and clears loading state")
    func reportsFileOperationFailures() async {
        let file = StubHostsFile(content: "")
        let model = makeViewModel(file: file)
        file.readError = StubHostsFileError.read

        await model.loadHosts()

        #expect(model.errorMessage == "Load failed: read failed")
        #expect(model.isLoading == false)

        model.entries = [HostEntry(type: .entry(ip: "127.0.0.1", domains: ["app.test"], isEnabled: true, comment: nil))]
        file.writeError = StubHostsFileError.write
        await model.saveHosts()

        #expect(model.errorMessage == "Save failed: write failed")
        #expect(model.isLoading == false)
    }

    private func makeViewModel(file: StubHostsFile) -> HostsManagerViewModel {
        HostsManagerViewModel(
            readHostsFile: { try await file.read() },
            writeHostsFile: { try await file.write($0) }
        )
    }
}

@MainActor
private final class StubHostsFile {
    private(set) var content: String
    private(set) var writes: [String] = []
    var readError: Error?
    var writeError: Error?

    init(content: String) {
        self.content = content
    }

    func read() async throws -> String {
        if let readError { throw readError }
        return content
    }

    func write(_ value: String) async throws {
        if let writeError { throw writeError }
        writes.append(value)
        content = value
    }
}

private enum StubHostsFileError: LocalizedError {
    case read
    case write

    var errorDescription: String? {
        switch self {
        case .read: "read failed"
        case .write: "write failed"
        }
    }
}
