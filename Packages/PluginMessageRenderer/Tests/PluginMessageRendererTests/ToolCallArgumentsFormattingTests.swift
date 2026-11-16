import Foundation
import ProviderMessage
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// 工具调用参数展示文本的准备契约（Issue #1186）。
///
/// 1. 格式化不在主 actor 上执行；
/// 2. 同一「工具调用 id + 参数版本」只格式化一次；
/// 3. 参数版本变化不得复用旧结果；
/// 4. await 期间身份已变时丢弃结果，不写缓存也不写回视图；
/// 5. body 求值本身不做任何格式化。
///
/// 缓存与格式化器都经 TaskLocal 注入独立实例：进程级 `shared` 会被并行
/// 用例清空，计数断言就会随机失败。
@MainActor
@Suite("工具调用参数准备", .serialized)
struct ToolCallArgumentsFormattingTests {

    // MARK: - 探针

    /// 记录格式化次数与所在 executor，可选门闩用于构造「旧请求晚到」。
    private final class FormatProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var calls = 0
        private var mainThreadHits = 0
        private var entered = false
        private var released = false
        private let gate: DispatchSemaphore?

        init(gated: Bool = false) {
            gate = gated ? DispatchSemaphore(value: 0) : nil
        }

        var callCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return calls
        }

        var mainThreadCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return mainThreadHits
        }

        var hasEntered: Bool {
            lock.lock()
            defer { lock.unlock() }
            return entered
        }

        func format(_ arguments: String) -> String? {
            lock.lock()
            calls += 1
            entered = true
            if pthread_main_np() != 0 { mainThreadHits += 1 }
            let shouldWait = !released
            lock.unlock()

            // 安全网超时：断言失败时不能把整个测试套件挂死。
            // 门闩只拦第一次；放开后同一探针的后续调用不再等待。
            if shouldWait { gate?.wait(timeout: .now() + 5) }
            return MessageViewHelpers.formatToolCallArguments(arguments)
        }

        func release() {
            lock.lock()
            released = true
            lock.unlock()
            gate?.signal()
        }
    }

    private func waitUntilEntered(_ probe: FormatProbe) async {
        let deadline = Date().addingTimeInterval(5)
        while !probe.hasEntered, Date() < deadline {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    private let payload = #"{"b":1,"a":2}"#

    private func toolCall(arguments: String) -> MessageToolCall {
        MessageToolCall(id: "call-1", name: "write_file", arguments: arguments)
    }

    // MARK: - executor 与缓存

    @Test("格式化在后台执行，不占用主 actor")
    func formattingRunsOffTheMainActor() async throws {
        let probe = FormatProbe()
        let cache = ToolCallArgumentsFormatCache()

        let outcome = await ToolCallArgumentsFormatting.$cache.withValue(cache) {
            await ToolCallArgumentsFormatting.$formatter.withValue({ probe.format($0) }) {
                await ToolCallArgumentsFormatting.prepare(
                    id: "call-1",
                    arguments: payload,
                    isStillCurrent: { true }
                )
            }
        }

        guard case .ready(let formatted) = outcome else {
            Issue.record("期望 .ready，实际 \(outcome)")
            return
        }
        let text = try #require(formatted)
        #expect(text.contains("\n"))
        // sortedKeys：a 在 b 之前。
        let indexA = try #require(text.range(of: "\"a\""))
        let indexB = try #require(text.range(of: "\"b\""))
        #expect(indexA.lowerBound < indexB.lowerBound)
        #expect(probe.callCount == 1)
        #expect(probe.mainThreadCount == 0)
    }

    @Test("同一参数版本只格式化一次")
    func repeatedPreparationHitsCache() async {
        let probe = FormatProbe()
        let cache = ToolCallArgumentsFormatCache()

        await ToolCallArgumentsFormatting.$cache.withValue(cache) {
            await ToolCallArgumentsFormatting.$formatter.withValue({ probe.format($0) }) {
                _ = await ToolCallArgumentsFormatting.prepare(id: "call-1", arguments: payload, isStillCurrent: { true })
                _ = await ToolCallArgumentsFormatting.prepare(id: "call-1", arguments: payload, isStillCurrent: { true })
            }
        }

        #expect(probe.callCount == 1)
    }

    @Test("参数版本变化后重新格式化，不复用旧结果")
    func changedArgumentsReformat() async throws {
        let probe = FormatProbe()
        let cache = ToolCallArgumentsFormatCache()
        let updated = #"{"b":1,"a":2,"c":3}"#

        let outcome = await ToolCallArgumentsFormatting.$cache.withValue(cache) {
            await ToolCallArgumentsFormatting.$formatter.withValue({ probe.format($0) }) {
                _ = await ToolCallArgumentsFormatting.prepare(id: "call-1", arguments: payload, isStillCurrent: { true })
                return await ToolCallArgumentsFormatting.prepare(id: "call-1", arguments: updated, isStillCurrent: { true })
            }
        }

        guard case .ready(let formatted) = outcome else {
            Issue.record("期望 .ready，实际 \(outcome)")
            return
        }
        #expect(try #require(formatted).contains("\"c\""))
        #expect(probe.callCount == 2)
    }

    @Test("空参数返回 ready(nil)，仍然只格式化一次")
    func emptyPayloadIsReadyNil() async {
        let probe = FormatProbe()
        let cache = ToolCallArgumentsFormatCache()

        let outcome = await ToolCallArgumentsFormatting.$cache.withValue(cache) {
            await ToolCallArgumentsFormatting.$formatter.withValue({ probe.format($0) }) {
                await ToolCallArgumentsFormatting.prepare(id: "call-1", arguments: "{}", isStillCurrent: { true })
            }
        }

        guard case .ready(let formatted) = outcome else {
            Issue.record("期望 .ready，实际 \(outcome)")
            return
        }
        #expect(formatted == nil)
        #expect(probe.callCount == 1)
    }

    // MARK: - 身份校验

    @Test("旧请求晚到时丢弃结果，不写缓存也不写回")
    func staleOutcomeIsNotWrittenBack() async throws {
        let probe = FormatProbe(gated: true)
        let cache = ToolCallArgumentsFormatCache()

        let late = Task {
            await ToolCallArgumentsFormatting.$cache.withValue(cache) {
                await ToolCallArgumentsFormatting.$formatter.withValue({ probe.format($0) }) {
                    await ToolCallArgumentsFormatting.prepare(
                        id: "call-1",
                        arguments: payload,
                        // await 期间用户已切到别的工具调用。
                        isStillCurrent: { false }
                    )
                }
            }
        }

        await waitUntilEntered(probe)
        probe.release()
        let outcome = await late.value

        guard case .stale = outcome else {
            Issue.record("期望 .stale，实际 \(outcome)")
            return
        }
        // 过期结果不得进缓存：否则下一次打开会直接命中旧文本。
        #expect(cache.entry(for: "call-1", arguments: payload) == nil)

        // 当前身份重新准备时必须真正格式化，而不是读到过期条目。
        let current = await ToolCallArgumentsFormatting.$cache.withValue(cache) {
            await ToolCallArgumentsFormatting.$formatter.withValue({ probe.format($0) }) {
                await ToolCallArgumentsFormatting.prepare(id: "call-1", arguments: payload, isStillCurrent: { true })
            }
        }
        guard case .ready = current else {
            Issue.record("期望 .ready，实际 \(current)")
            return
        }
        #expect(probe.callCount == 2)
    }

    // MARK: - 缓存边界

    @Test("缓存按参数版本校验，版本不同不命中")
    func cacheRejectsDifferentRevision() {
        let cache = ToolCallArgumentsFormatCache()
        cache.store("旧文本", for: "call-1", arguments: payload)

        #expect(cache.entry(for: "call-1", arguments: payload)?.formatted == "旧文本")
        #expect(cache.entry(for: "call-1", arguments: #"{"a":9}"#) == nil)
        #expect(cache.entry(for: "call-2", arguments: payload) == nil)
    }

    @Test("缓存有界，超出上限淘汰最早条目")
    func cacheIsBounded() {
        let cache = ToolCallArgumentsFormatCache(limit: 2)
        cache.store("一", for: "call-1", arguments: payload)
        cache.store("二", for: "call-2", arguments: payload)
        cache.store("三", for: "call-3", arguments: payload)

        #expect(cache.entry(for: "call-1", arguments: payload) == nil)
        #expect(cache.entry(for: "call-2", arguments: payload)?.formatted == "二")
        #expect(cache.entry(for: "call-3", arguments: payload)?.formatted == "三")
    }

    @Test("同一 id 覆盖写入不重复占用淘汰名额")
    func replacingEntryDoesNotGrowOrder() {
        let cache = ToolCallArgumentsFormatCache(limit: 2)
        cache.store("一", for: "call-1", arguments: payload)
        cache.store("二", for: "call-2", arguments: payload)
        cache.store("三", for: "call-1", arguments: #"{"a":9}"#)

        #expect(cache.entry(for: "call-1", arguments: #"{"a":9}"#)?.formatted == "三")
        #expect(cache.entry(for: "call-2", arguments: payload)?.formatted == "二")
    }

    // MARK: - body 不做格式化

    @Test("body 求值不解析也不序列化参数")
    func bodyDoesNotFormatArguments() {
        let probe = FormatProbe()
        let cache = ToolCallArgumentsFormatCache()
        let call = toolCall(arguments: payload)
        // 三个分支都要覆盖：已准备好文本、尚未准备好、准备好的版本已过期。
        // 只测 loading 分支会让「body 里同步格式化」的回归悄悄通过。
        let ready = ToolCallArgumentsView(
            toolCall: call,
            prepared: .init(arguments: payload, formatted: "{\n  \"a\" : 2\n}")
        )
        let loading = ToolCallArgumentsView(toolCall: call)
        let outdated = ToolCallArgumentsView(
            toolCall: toolCall(arguments: #"{"b":1,"a":2,"c":3}"#),
            prepared: .init(arguments: payload, formatted: "旧文本")
        )

        ToolCallArgumentsFormatting.$cache.withValue(cache) {
            ToolCallArgumentsFormatting.$formatter.withValue({ probe.format($0) }) {
                for view in [ready, loading, outdated] {
                    _ = view.body
                    _ = view.body
                }
            }
        }

        // 修复前：每次 body 求值都会同步格式化一遍。
        #expect(probe.callCount == 0)
    }
}