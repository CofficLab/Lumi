import Foundation
import Testing
@testable import KitSuperLog

// 简单 SuperLog 实现，用于测试协议扩展
private class PlainLogger: SuperLog {}
private class Generic<A, B>: SuperLog {}
private class CustomEmoji: SuperLog {
    static let emoji = "🛠️"
}

@Suite("SuperLog 协议扩展补充")
struct SuperLogExtensionTests {

    // MARK: - ms 格式化

    @Test("ms 把 Duration 格式化为毫秒字符串")
    func msFormatsDuration() {
        #expect(PlainLogger.ms(.seconds(1)) == "1000.00")
        #expect(PlainLogger.ms(.milliseconds(12)) == "12.00")
        // 0.5s = 500ms（1s = 1e18 attoseconds）
        let halfSecond = Duration(secondsComponent: 0, attosecondsComponent: 500_000_000_000_000_000)
        #expect(PlainLogger.ms(halfSecond) == "500.00")
        // 1.5s = 1500ms
        let oneFifty = Duration(secondsComponent: 1, attosecondsComponent: 500_000_000_000_000_000)
        #expect(PlainLogger.ms(oneFifty) == "1500.00")
    }

    // MARK: - author 截断泛型

    @Test("author 剥掉泛型实参 <...>")
    func authorStripsGenericArguments() {
        #expect(Generic<Int, String>.author == "Generic")
        #expect(PlainLogger.author == "PlainLogger")
    }

    // MARK: - reason 包装

    @Test("makeReason 加上 ➡️ 前缀")
    func makeReasonWraps() {
        let inst = PlainLogger()
        #expect(inst.r("密码错误") == " ➡️ 密码错误")
        #expect(inst.makeReason("x") == " ➡️ x")
    }

    // MARK: - 固定前缀

    @Test("onAppear / onInit 包含标识与动作前缀")
    func onAppearOnInitPrefixes() {
        #expect(CustomEmoji.onAppear.contains("🛠️"))
        #expect(CustomEmoji.onAppear.contains("📺 OnAppear"))
        #expect(CustomEmoji.onInit.contains("🚩 Init"))
        #expect(CustomEmoji.i.contains("🚩 Init"))
        #expect(CustomEmoji.a.contains("📺 OnAppear"))
    }

    // MARK: - 实例便捷属性

    @Test("实例 author/className 与 Self.author 一致，isMain 可读取")
    func instanceProperties() {
        let inst = PlainLogger()
        #expect(inst.author == "PlainLogger")
        #expect(inst.className == "PlainLogger")
        _ = inst.isMain  // 不崩溃即可
    }
}

@Suite("MagicLogger 级别路由补充")
struct MagicLoggerLevelTests {

    @Test("info/warning/error/debug 写入对应级别的条目")
    func levelRouting() async throws {
        let logger = MagicLogger(app: "TestApp")
        logger.clearLogs()

        logger.info("info msg")
        logger.warning("warn msg")
        logger.error("err msg")
        logger.debug("dbg msg")

        // addLog 派发到主队列异步追加，让出主线程后再断言
        try await Task.sleep(for: Duration.milliseconds(200))

        #expect(logger.logs.count == 4)
        let levels = logger.logs.map(\.level)
        #expect(levels[0] == .info)
        #expect(levels[1] == .warning)
        #expect(levels[2] == .error)
        #expect(levels[3] == .debug)
        #expect(logger.logs[0].originalMessage == "info msg")
    }

    @Test("静态 log(_:level:) 路由到 shared 且文件路径被截断")
    func staticLogRoutesToShared() async throws {
        MagicLogger.clearLogs()
        MagicLogger.log("static err", level: .error, caller: "Sources/Foo/Bar.swift")

        try await Task.sleep(for: Duration.milliseconds(200))

        // 至少应有一条 error
        #expect(MagicLogger.shared.logs.contains(where: { $0.level == .error && $0.originalMessage == "static err" }))
        // caller 应去掉目录与扩展名 → "Bar"
        #expect(MagicLogger.shared.logs.contains(where: { $0.caller == "Bar" }))
    }
}
