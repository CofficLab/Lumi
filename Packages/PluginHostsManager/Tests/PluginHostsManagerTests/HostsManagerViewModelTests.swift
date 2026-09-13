import Testing
@testable import PluginHostsManager

@Suite("Hosts manager view model")
@MainActor
struct HostsManagerViewModelTests {
    @Test("filters entries by group and only shows groups that contain search matches")
    func filtersByGroupAndSearch() {
        let model = HostsManagerViewModel()
        model.entries = HostsParser.parse(content: """
        # GROUP: Alpha
        127.0.0.1 alpha.test # development
        # GROUP: Beta
        127.0.0.2 beta.test # Operations
        # GROUP: Gamma
        127.0.0.3 gamma.test
        """)

        #expect(model.groups == ["Alpha", "Beta", "Gamma"])
        model.selectedGroup = "Alpha"
        #expect(model.filteredEntries.map(\.type) == [
            .groupHeader("Alpha"),
            .entry(ip: "127.0.0.1", domains: ["alpha.test"], isEnabled: true, comment: "development"),
        ])

        model.selectedGroup = nil
        model.searchText = "OPERATIONS"
        #expect(model.filteredEntries.map(\.type) == [
            .groupHeader("Beta"),
            .entry(ip: "127.0.0.2", domains: ["beta.test"], isEnabled: true, comment: "Operations"),
        ])
    }

    @Test("rejects invalid new entries without mutating the list")
    func rejectsInvalidEntry() {
        let model = HostsManagerViewModel()
        model.addEntry(ip: "not-an-ip", domain: "valid.test", comment: nil, group: nil)

        #expect(model.entries.isEmpty)
        #expect(model.errorMessage == "Invalid host entry")
        #expect(model.isValidDomainList("one.test two.test"))
        #expect(model.isValidDomainList("one.test invalid..test") == false)
    }

    @Test("adds, toggles, and deletes entries through the save and reload flow")
    func mutatesEntriesAndPersists() async throws {
        let file = StubHostsFileForMutations()
        let model = HostsManagerViewModel(
            readHostsFile: { try await file.read() },
            writeHostsFile: { try await file.write($0) }
        )

        model.addEntry(
            ip: " 127.0.0.1 ",
            domain: "one.test\t two.test",
            comment: " local ",
            group: "Development"
        )
        await waitForSave(count: 1, model: model, file: file)

        #expect(file.writes[0] == "\n# GROUP: Development\n127.0.0.1 one.test two.test # local\n")
        let entry = model.entries.first { $0.ip == "127.0.0.1" }
        let savedEntry = try #require(entry)
        #expect(savedEntry.isEnabled)

        model.toggleEntry(savedEntry)
        await waitForSave(count: 2, model: model, file: file)
        #expect(file.writes[1].contains("# 127.0.0.1 one.test two.test # local"))
        #expect(model.entries.first { $0.ip == "127.0.0.1" }?.isEnabled == false)

        let disabledEntry = try #require(model.entries.first { $0.ip == "127.0.0.1" })
        model.deleteEntry(disabledEntry)
        await waitForSave(count: 3, model: model, file: file)
        #expect(model.entries.contains { $0.ip == "127.0.0.1" } == false)
    }

    private func waitForSave(count: Int, model: HostsManagerViewModel, file: StubHostsFileForMutations) async {
        for _ in 0..<100 {
            if file.writes.count >= count, !model.isLoading { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}

@MainActor
private final class StubHostsFileForMutations {
    private(set) var content = ""
    private(set) var writes: [String] = []

    func read() async throws -> String { content }

    func write(_ value: String) async throws {
        writes.append(value)
        content = value
    }
}
