import Foundation
import Testing
@testable import BrowserPlugin

/// 回归 #834：browser_snapshot 带 role/name/text 过滤时走 find 分支，曾完全丢掉
/// interactive_only，导致 heading 等非交互节点仍被返回。`filterInteractive` 是从
/// find 分支抽出的纯过滤逻辑，这里锁定它与 interactive_only 标志的组合行为
/// （不依赖真实 WebView，与快照树过滤共用同一 isInteractive 判据）。
struct BrowserSnapshotInteractiveFilterTests {

    private func node(_ ref: String, _ role: String, _ name: String) -> BrowserAccessibilityNode {
        BrowserAccessibilityNode(ref: ref, role: role, name: name)
    }

    @Test func interactiveFilterDropsHeadingWhenInteractiveOnly() {
        let matches = [node("lumi-1", "heading", "Welcome"), node("lumi-2", "button", "Submit")]
        let visible = BrowserAccessibilityNode.filterInteractive(matches, interactiveOnly: true)
        #expect(visible.count == 1)
        #expect(visible[0].ref == "lumi-2")
        #expect(visible[0].role == "button")
    }

    @Test func interactiveFilterDisabledKeepsAllMatches() {
        let matches = [
            node("lumi-1", "heading", "Welcome"),
            node("lumi-2", "button", "Submit"),
            node("lumi-3", "link", "Docs"),
        ]
        let visible = BrowserAccessibilityNode.filterInteractive(matches, interactiveOnly: false)
        #expect(visible.map { $0.ref } == ["lumi-1", "lumi-2", "lumi-3"])
    }

    @Test func interactiveFilterKeepsOnlyInteractiveRoles() {
        let matches = [
            node("lumi-1", "button", "A"),
            node("lumi-2", "link", "B"),
            node("lumi-3", "textbox", "C"),
            node("lumi-4", "paragraph", "D"),
            node("lumi-5", "heading", "E"),
        ]
        let visible = BrowserAccessibilityNode.filterInteractive(matches, interactiveOnly: true)
        #expect(visible.map { $0.ref } == ["lumi-1", "lumi-2", "lumi-3"])
    }

    @Test func interactiveFilterKeepsAllWhenAllInteractive() {
        let matches = [node("lumi-1", "button", "A"), node("lumi-2", "link", "B")]
        let visible = BrowserAccessibilityNode.filterInteractive(matches, interactiveOnly: true)
        #expect(visible.map { $0.ref } == ["lumi-1", "lumi-2"])
    }

    @Test func interactiveFilterReturnsEmptyWhenNoneInteractive() {
        let matches = [node("lumi-1", "heading", "Welcome"), node("lumi-2", "paragraph", "text")]
        let visible = BrowserAccessibilityNode.filterInteractive(matches, interactiveOnly: true)
        #expect(visible.isEmpty)
    }

    @Test func interactiveFilterOnEmptyMatchesReturnsEmpty() {
        let visible = BrowserAccessibilityNode.filterInteractive([], interactiveOnly: true)
        #expect(visible.isEmpty)
    }
}