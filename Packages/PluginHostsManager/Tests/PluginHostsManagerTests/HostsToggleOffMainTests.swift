import Foundation
import Testing
@testable import PluginHostsManager

/// Hosts 开关 / 加载 / 保存的主线程占用（见 issue #1205）。
///
/// 每次切换条目都会序列化整份 hosts、写临时文件、再读回并重新解析；
/// 这些随文件大小增长的工作原先全部在主 actor 上同步执行。
@MainActor
@Suite("Hosts 开关 off-main (#1205)")
struct HostsToggleOffMainTests {

    @Test("解析与序列化在后台线程执行且往返一致")
    func parseAndSerializeRunOffMain() async throws {
        let content = "# GROUP: Dev\n127.0.0.1 app.test # note\n# 127.0.0.2 off.test\n"
        let flag = ThreadFlag()

        let roundTrip = await Task.detached(priority: .userInitiated) {
            Self.runParseSerializeOffMain(content: content, flag: flag)
        }.value

        #expect(flag.value == false, "hosts 解析/序列化不应发生在主线程")
        #expect(roundTrip == content)
    }

    @Test("晚到的旧加载不覆盖最新 entries")
    func staleLoadDoesNotOverwriteNewerEntries() async throws {
        let file = GatedHostsReads()
        file.content = "127.0.0.1 first.test\n"
        file.blockFirst = true
        let model = HostsManagerViewModel(
            readHostsFile: { try await file.read() },
            writeHostsFile: { _ in }
        )

        // L1 读取被挂起，模拟慢盘 / 大文件。
        let first = Task { @MainActor in await model.loadHosts() }
        await waitUntil { file.reads == 1 }

        // L2 在 L1 仍挂起时发起并先完成。
        file.content = "127.0.0.1 second.test\n"
        let second = Task { @MainActor in await model.loadHosts() }
        await second.value
        #expect(model.entries.contains { $0.domains == ["second.test"] })

        // 放行 L1：它的过期内容不得覆盖 L2 的结果。
        file.release()
        await first.value

        #expect(model.entries.contains { $0.domains == ["second.test"] })
        #expect(!model.entries.contains { $0.domains == ["first.test"] })
        #expect(model.isLoading == false)
    }

    @Test("切换条目后落盘的是切换后的快照")
    func toggleWritesToggledSnapshot() async throws {
        let file = RecordingHostsFile()
        file.content = "127.0.0.1 app.test\n"
        let model = HostsManagerViewModel(
            readHostsFile: { try await file.read() },
            writeHostsFile: { try await file.write($0) }
        )
        await model.loadHosts()

        let entry = try #require(model.entries.first)
        model.toggleEntry(entry)
        await waitUntil { file.writes.count == 1 }

        #expect(file.writes.first == "# 127.0.0.1 app.test\n")
    }

    // MARK: - Helpers

    /// 同步执行，才能在闭包内读取 `Thread.isMainThread`（异步上下文不可用）。
    nonisolated private static func runParseSerializeOffMain(content: String, flag: ThreadFlag) -> String {
        flag.value = Thread.isMainThread
        return HostsParser.serialize(entries: HostsParser.parse(content: content))
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}

/// 第一次读取挂起在门闩上，但返回的是调用时刻的内容快照。
@MainActor
private final class GatedHostsReads {
    var content = ""
    var blockFirst = false
    private(set) var reads = 0
    private var gate: CheckedContinuation<Void, Never>?

    func read() async throws -> String {
        reads += 1
        let snapshot = content
        if blockFirst {
            blockFirst = false
            await withCheckedContinuation { gate = $0 }
        }
        return snapshot
    }

    func release() {
        gate?.resume()
        gate = nil
    }
}

@MainActor
private final class RecordingHostsFile {
    var content = ""
    private(set) var writes: [String] = []

    func read() async throws -> String { content }

    func write(_ value: String) async throws {
        writes.append(value)
        content = value
    }
}

private final class ThreadFlag: @unchecked Sendable {
    var value = false
}