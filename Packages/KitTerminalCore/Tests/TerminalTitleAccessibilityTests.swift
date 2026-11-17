import AppKit
import Combine
import Testing
@testable import KitTerminalCore

/// 回归 #1232：此前每个 OSC 标题事件都新建 MainActor Task 并无条件发布
/// `@Published title`，重复标题反复触发 SwiftUI 失效。修复后主线程直接
/// 应用且与当前标题相同则跳过发布。
@MainActor
@Suite("终端标题更新")
struct TerminalSessionTitleTests {

    @Test("重复 OSC 标题不得重复发布")
    func duplicateTitleDoesNotRepublish() {
        let session = TerminalSession()
        var publications = 0
        let cancellable = session.$title.dropFirst().sink { _ in publications += 1 }

        session.setTerminalTitle(source: session.terminalView, title: "build-result")
        session.setTerminalTitle(source: session.terminalView, title: "build-result")

        #expect(session.title == "build-result")
        #expect(publications == 1)
        cancellable.cancel()
    }

    @Test("主线程同步应用标题且空标题归一化为 Terminal")
    func titleAppliesSynchronouslyOnMainAndNormalizesEmpty() {
        let session = TerminalSession()
        // 若实现退化为 Task 投递，同步读取时仍是初始值。
        session.setTerminalTitle(source: session.terminalView, title: "working-dir")
        #expect(session.title == "working-dir")

        session.setTerminalTitle(source: session.terminalView, title: "")
        #expect(session.title == "Terminal")
    }
}

/// 回归 #1233：accessibilityValue 从 row 0 取到可见区末尾，滚动后把整段
/// scrollback 一并重建，每次查询代价与缓冲区总行数成正比。修复后只取
/// 可见视口。
@MainActor
@Suite("终端无障碍值")
struct LumiTerminalViewAccessibilityTests {

    @Test("无障碍值只含可见视口而非 scrollback")
    func accessibilityValueCoversViewportOnly() {
        let view = LumiTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let terminal = view.getTerminal()

        let total = terminal.rows + 30
        view.feed(text: (1...total).map { "line\($0)" }.joined(separator: "\r\n"))
        let top = terminal.getTopVisibleRow()
        #expect(top > 0)

        let value = (view.accessibilityValue() as? String) ?? ""
        let lines = value.split(separator: "\n").map(String.init)
        // 视口首行是缓冲区第 top 行（0 计数）的内容，scrollback 首行不应出现。
        #expect(lines.first == "line\(top + 1)")
        #expect(!lines.contains("line1"))
        #expect(lines.contains("line\(total)"))
    }
}
