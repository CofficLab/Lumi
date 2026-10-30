import Foundation
import Testing
@testable import BrowserPlugin

/// 可访问性快照的纯逻辑测试。
///
/// 这些用例覆盖不依赖真实 WebView 的部分：解析、建树、渲染、筛选。
/// 页面脚本本身由浏览器执行，无法在单元测试里跑，因此这里锁定
/// 「脚本返回什么 → Swift 侧产出什么」的契约。
@Suite("Browser 可访问性快照")
struct BrowserAccessibilityNodeTests {
    /// 构造一个脚本返回的原始节点。
    private func raw(
        ref: String,
        role: String,
        name: String,
        parent: Int = -1,
        value: String? = nil,
        href: String? = nil,
        disabled: Bool = false,
        checked: Bool? = nil,
        selected: Bool = false,
        expanded: Bool? = nil,
        required: Bool = false,
        focused: Bool = false,
        level: Int? = nil
    ) -> [String: Any] {
        var item: [String: Any] = [
            "ref": ref,
            "role": role,
            "name": name,
            "parent": parent,
        ]
        if let value { item["value"] = value }
        if let href { item["href"] = href }
        if disabled { item["disabled"] = true }
        if let checked { item["checked"] = checked }
        if selected { item["selected"] = true }
        if let expanded { item["expanded"] = expanded }
        if required { item["required"] = true }
        if focused { item["focused"] = true }
        if let level { item["level"] = level }
        return item
    }

    @Test("扁平列表被重建为树结构")
    func buildsTreeFromFlatList() {
        let nodes = BrowserAccessibilityNode.parseList([
            raw(ref: "lumi-1", role: "navigation", name: "Main"),
            raw(ref: "lumi-2", role: "link", name: "Home", parent: 0),
            raw(ref: "lumi-3", role: "link", name: "Docs", parent: 0),
        ])

        let tree = BrowserAccessibilityNode.buildTree(from: nodes)

        #expect(tree.count == 1)
        #expect(tree[0].ref == "lumi-1")
        #expect(tree[0].children.count == 2)
        #expect(tree[0].children[0].name == "Home")
        #expect(tree[0].children[1].name == "Docs")
    }

    @Test("父节点必须排在子节点之前，否则该节点被当作根")
    func toleratesOutOfOrderParents() {
        // 子节点出现在父节点之前：不能递归爆栈，也不能丢失节点。
        let nodes = BrowserAccessibilityNode.parseList([
            raw(ref: "lumi-2", role: "link", name: "Orphan", parent: 5),
            raw(ref: "lumi-1", role: "navigation", name: "Main"),
        ])

        let tree = BrowserAccessibilityNode.buildTree(from: nodes)

        #expect(tree.count == 2)
        let all = tree.flatMap { BrowserAccessibilityNode.descendants(of: $0) }
        #expect(all.count == 2)
    }

    @Test("渲染输出包含 ref、角色、名称与状态")
    func rendersRoleNameAndState() {
        let nodes = BrowserAccessibilityNode.parseList([
            raw(ref: "lumi-1", role: "button", name: "登录", disabled: true),
            raw(ref: "lumi-2", role: "textbox", name: "邮箱", value: "a@b.com"),
            raw(ref: "lumi-3", role: "link", name: "首页", href: "https://example.com"),
        ])

        let lines = BrowserAccessibilityNode.renderLines(BrowserAccessibilityNode.buildTree(from: nodes))

        #expect(lines.count == 3)
        #expect(lines[0] == "@lumi-1 button \"登录\" [disabled]")
        #expect(lines[1] == "@lumi-2 textbox \"邮箱\" value=\"a@b.com\"")
        #expect(lines[2] == "@lumi-3 link \"首页\" → https://example.com")
    }

    @Test("空名称渲染为占位符而不是空引号")
    func rendersPlaceholderForEmptyName() {
        let nodes = BrowserAccessibilityNode.parseList([
            raw(ref: "lumi-1", role: "button", name: ""),
        ])

        let lines = BrowserAccessibilityNode.renderLines(BrowserAccessibilityNode.buildTree(from: nodes))

        #expect(lines[0] == "@lumi-1 button \"(no name)\"")
    }

    @Test("状态标记顺序固定，便于逐行 diff")
    func rendersStateFlagsInFixedOrder() {
        let nodes = BrowserAccessibilityNode.parseList([
            raw(
                ref: "lumi-1",
                role: "checkbox",
                name: "同意",
                disabled: true,
                checked: false,
                required: true,
                focused: true
            ),
        ])

        let lines = BrowserAccessibilityNode.renderLines(BrowserAccessibilityNode.buildTree(from: nodes))

        #expect(lines[0] == "@lumi-1 checkbox \"同意\" [disabled unchecked required focused]")
    }

    @Test("interactive_only 过滤掉非交互的叶子，但保留仍有交互后代的分支")
    func prunesNonInteractiveLeaves() {
        let nodes = BrowserAccessibilityNode.parseList([
            raw(ref: "lumi-1", role: "banner", name: "Header"),
            raw(ref: "lumi-2", role: "button", name: "Menu", parent: 0),
            raw(ref: "lumi-3", role: "paragraph", name: "Just text"),
        ])
        let tree = BrowserAccessibilityNode.buildTree(from: nodes)

        let snapshot = BrowserAccessibilitySnapshot(
            pageTitle: "T",
            pageURL: "https://example.com",
            roots: tree,
            totalNodeCount: 3
        )
        let filtered = snapshot.filteredNodes(interactiveOnly: true)

        #expect(filtered.count == 1)
        #expect(filtered[0].ref == "lumi-1")
        #expect(filtered[0].children.count == 1)
        #expect(filtered[0].children[0].ref == "lumi-2")
    }

    @Test("可交互角色判定覆盖常用表单控件")
    func identifiesInteractiveRoles() {
        func node(_ role: String) -> BrowserAccessibilityNode {
            BrowserAccessibilityNode(ref: "lumi-1", role: role, name: "x")
        }

        #expect(node("button").isInteractive)
        #expect(node("link").isInteractive)
        #expect(node("textbox").isInteractive)
        #expect(node("checkbox").isInteractive)
        #expect(node("combobox").isInteractive)
        #expect(node("paragraph").isInteractive == false)
        #expect(node("heading").isInteractive == false)
    }
}
