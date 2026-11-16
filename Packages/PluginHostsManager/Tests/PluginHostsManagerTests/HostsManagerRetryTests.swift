import Foundation
import Testing
@testable import PluginHostsManager

/// Hosts 错误横幅 Retry 的行为（#458）。
///
/// 修改操作先改内存 `entries` 再异步保存；保存失败时编辑仍未落盘。以往 Retry
/// 固定调用 `loadHosts()`，会用磁盘旧内容覆盖内存，静默丢弃未保存的编辑。
/// 修复后 Retry 按最近一次失败的操作类型分派：保存失败重试保存（保留编辑），
/// 加载失败重新从磁盘加载。
@Suite("Hosts manager retry (#458)")
@MainActor
struct HostsManagerRetryTests {
    @Test("保存失败后 Retry 必须重试保存，不得用磁盘旧内容丢弃未落盘编辑（回归 #458）")
    func retryAfterFailedSaveResavesAndKeepsEdits() async {
        let file = FailableHostsFile(content: "")
        file.failWritesRemaining = 1            // 首次写入失败（模拟取消管理员授权）
        let model = makeViewModel(file: file)

        await model.loadHosts()
        #expect(!model.entries.contains { $0.domains == ["kept.test"] })

        model.addEntry(ip: "127.0.0.1", domain: "kept.test", comment: nil, group: nil)
        await waitUntil { file.writes.count == 1 && !model.isLoading }

        // 保存失败：编辑仍在内存，磁盘未落盘，错误横幅出现。
        #expect(model.errorMessage != nil)
        #expect(model.entries.contains { $0.domains == ["kept.test"] })
        #expect(file.content.isEmpty)

        // Retry 必须重试保存，而不是 reload 磁盘把编辑丢弃。
        await model.retry()
        await waitUntil { !model.isLoading }

        #expect(file.writes.count == 2)
        #expect(file.content.contains("kept.test"))
        #expect(model.entries.contains { $0.domains == ["kept.test"] })
        #expect(model.errorMessage == nil)
    }

    @Test("加载失败后 Retry 重新从磁盘加载，不触发保存")
    func retryAfterFailedLoadReloadsFromDisk() async {
        let file = FailableHostsFile(content: "127.0.0.1 disk.test")
        file.failReadsRemaining = 1
        let model = makeViewModel(file: file)

        await model.loadHosts()                  // 首次读取失败
        #expect(model.errorMessage != nil)
        #expect(file.reads == 1)

        await model.retry()                      // 加载失败 → 重新加载
        await waitUntil { !model.isLoading }

        #expect(file.reads == 2)
        #expect(file.writes.isEmpty)
        #expect(model.entries.contains { $0.domains == ["disk.test"] })
        #expect(model.errorMessage == nil)
    }

    @Test("校验错误不得把待重试的保存降级为重新加载（回归 #458）")
    func validationErrorDoesNotDowngradePendingSaveRetry() async {
        let file = FailableHostsFile(content: "")
        file.failWritesRemaining = 1
        let model = makeViewModel(file: file)

        await model.loadHosts()
        model.addEntry(ip: "127.0.0.1", domain: "kept.test", comment: nil, group: nil)
        await waitUntil { file.writes.count == 1 && !model.isLoading }
        #expect(model.entries.contains { $0.domains == ["kept.test"] })

        // 待重试保存期间又触发一次校验错误：不得把 Retry 降级成 reload 而丢弃编辑。
        model.addEntry(ip: "not-an-ip", domain: "bad.test", comment: nil, group: nil)
        #expect(model.errorMessage != nil)
        #expect(model.entries.contains { $0.domains == ["kept.test"] })

        await model.retry()
        await waitUntil { !model.isLoading }

        #expect(file.writes.count == 2)
        #expect(file.content.contains("kept.test"))
        #expect(model.entries.contains { $0.domains == ["kept.test"] })
    }

    private func makeViewModel(file: FailableHostsFile) -> HostsManagerViewModel {
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

/// 有状态的 hosts 文件替身：读取返回当前内容，写入可配置前 N 次失败。
/// 失败的写入不落盘（模拟取消授权），成功的写入更新内容供后续读取反映。
@MainActor
private final class FailableHostsFile {
    private(set) var content: String
    private(set) var writes: [String] = []
    private(set) var reads = 0
    var failWritesRemaining = 0
    var failReadsRemaining = 0

    init(content: String) { self.content = content }

    func read() async throws -> String {
        reads += 1
        if failReadsRemaining > 0 {
            failReadsRemaining -= 1
            throw DeniedError()
        }
        return content
    }

    func write(_ value: String) async throws {
        writes.append(value)
        if failWritesRemaining > 0 {
            failWritesRemaining -= 1
            throw DeniedError()
        }
        content = value
    }
}

private struct DeniedError: LocalizedError {
    var errorDescription: String? { "authorization denied" }
}