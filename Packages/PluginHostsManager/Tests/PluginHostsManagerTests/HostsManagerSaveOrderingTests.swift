import Foundation
import Testing
@testable import PluginHostsManager

@Suite("Hosts manager save ordering (#254)")
@MainActor
struct HostsManagerSaveOrderingTests {
    @Test("serializes concurrent saves so the newest snapshot is written last")
    func newestSnapshotWinsWhenFirstWriteIsDelayed() async {
        let file = GatedHostsFile()
        file.blockRemaining = 1
        let model = makeViewModel(file: file)

        // E1：第一次编辑，其写入开始后被挂起（模拟管理员授权未确认）。
        model.addEntry(ip: "127.0.0.1", domain: "first.test", comment: nil, group: nil)
        await waitUntil { file.writes.count == 1 }

        // E2：E1 仍挂起时做第二次编辑。
        model.addEntry(ip: "127.0.0.2", domain: "second.test", comment: nil, group: nil)
        for _ in 0..<20 { await Task.yield() }

        // 放行 E1 的迟到写入：串行链必须让 E2 的最新快照最后落盘。
        file.releaseOne()
        await waitUntil { file.completedWrites == 2 && !model.isLoading }

        #expect(file.content.contains("first.test"))
        #expect(file.content.contains("second.test"))
        #expect(model.entries.contains { $0.domains == ["first.test"] })
        #expect(model.entries.contains { $0.domains == ["second.test"] })
    }

    @Test("a stale save does not reload old content over the newest entries")
    func staleSaveSkipsReload() async {
        let file = GatedHostsFile()
        file.blockWrites = true
        let model = makeViewModel(file: file)

        model.addEntry(ip: "127.0.0.1", domain: "first.test", comment: nil, group: nil)
        await waitUntil { file.writes.count == 1 }

        model.addEntry(ip: "127.0.0.2", domain: "second.test", comment: nil, group: nil)
        for _ in 0..<20 { await Task.yield() }

        // 放行 S1；S2 随后开始并挂起。此时 S1 已是过期世代。
        file.releaseOne()
        await waitUntil { file.writes.count == 2 }
        for _ in 0..<20 { await Task.yield() }

        // 过期保存不得用只含 first.test 的旧内容覆盖最新 entries。
        #expect(model.entries.contains { $0.domains == ["second.test"] })
        #expect(model.entries.contains { $0.domains == ["first.test"] })

        file.releaseAll()
        await waitUntil { file.completedWrites == 2 && !model.isLoading }
        #expect(file.content.contains("second.test"))
    }

    private func makeViewModel(file: GatedHostsFile) -> HostsManagerViewModel {
        HostsManagerViewModel(
            readHostsFile: { try await file.read() },
            writeHostsFile: { try await file.write($0) }
        )
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}

@MainActor
private final class GatedHostsFile {
    private(set) var content = ""
    private(set) var writes: [String] = []
    private(set) var completedWrites = 0
    private var gates: [CheckedContinuation<Void, Never>] = []
    var blockWrites = false
    var blockRemaining = 0

    func read() async throws -> String { content }

    func write(_ value: String) async throws {
        writes.append(value)
        if blockWrites || blockRemaining > 0 {
            if blockRemaining > 0 { blockRemaining -= 1 }
            await withCheckedContinuation { gates.append($0) }
        }
        content = value
        completedWrites += 1
    }

    func releaseOne() {
        guard !gates.isEmpty else { return }
        gates.removeFirst().resume()
    }

    func releaseAll() {
        let pending = gates
        gates.removeAll()
        for gate in pending { gate.resume() }
    }
}