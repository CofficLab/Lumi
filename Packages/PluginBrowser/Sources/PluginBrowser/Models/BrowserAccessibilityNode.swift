import Foundation

/// 可访问性元素的状态标记。
///
/// 只保留页面明确声明过的状态（`aria-*` / 原生属性），缺失即为 `nil`，
/// 避免把「没有这个状态」和「状态为 false」混为一谈。
struct BrowserAccessibilityState: Sendable, Equatable {
    var disabled: Bool = false
    var checked: Bool?
    var selected: Bool = false
    var expanded: Bool?
    var required: Bool = false
    var focused: Bool = false
    var readOnly: Bool = false
    var invalid: Bool = false
    var level: Int?

    /// 状态标记的展示顺序固定，保证同一页面多次快照的输出逐行可 diff。
    var flags: [String] {
        var out: [String] = []
        if disabled { out.append("disabled") }
        if let checked { out.append(checked ? "checked" : "unchecked") }
        if selected { out.append("selected") }
        if let expanded { out.append(expanded ? "expanded" : "collapsed") }
        if required { out.append("required") }
        if readOnly { out.append("readonly") }
        if invalid { out.append("invalid") }
        if focused { out.append("focused") }
        if let level { out.append("level=\(level)") }
        return out
    }
}

/// 一个可访问性节点。
///
/// 解析阶段 `children` 为空、`parentIndex` 指向扁平列表中的父节点下标；
/// `buildTree(from:)` 会把扁平列表重建成真正的树。
struct BrowserAccessibilityNode: Sendable, Equatable {
    var ref: String
    var role: String
    var name: String
    var state: BrowserAccessibilityState = BrowserAccessibilityState()
    var value: String?
    var href: String?
    var parentIndex: Int = -1
    var children: [BrowserAccessibilityNode] = []

    /// 无可访问名称时的占位，避免输出中出现空的引号让 LLM 误判。
    var displayName: String { name.isEmpty ? "(no name)" : name }

    /// 是否是可交互角色（决定 `browser_snapshot` 的 interactive_only 过滤）。
    var isInteractive: Bool {
        switch role {
        case "button", "link", "textbox", "searchbox", "checkbox", "radio", "switch",
             "combobox", "listbox", "option", "slider", "spinbutton", "menuitem",
             "menuitemcheckbox", "menuitemradio", "tab", "treeitem":
            return true
        default:
            return false
        }
    }
}

// MARK: - 解析

extension BrowserAccessibilityNode {
    /// 从页面脚本返回的扁平数组解析节点列表。
    ///
    /// - Parameter raw: `[{ ref, role, name, parent, value, href, ...state }]`
    static func parseList(_ raw: [[String: Any]]) -> [BrowserAccessibilityNode] {
        raw.map { item in
            var node = BrowserAccessibilityNode(
                ref: item["ref"] as? String ?? "",
                role: item["role"] as? String ?? "generic",
                name: item["name"] as? String ?? ""
            )
            node.parentIndex = (item["parent"] as? Int) ?? -1
            node.value = (item["value"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            node.href = (item["href"] as? String).flatMap { $0.isEmpty ? nil : $0 }

            var state = BrowserAccessibilityState()
            state.disabled = (item["disabled"] as? Bool) ?? false
            state.checked = item["checked"] as? Bool
            state.selected = (item["selected"] as? Bool) ?? false
            state.expanded = item["expanded"] as? Bool
            state.required = (item["required"] as? Bool) ?? false
            state.focused = (item["focused"] as? Bool) ?? false
            state.readOnly = (item["readonly"] as? Bool) ?? false
            state.invalid = (item["invalid"] as? Bool) ?? false
            state.level = item["level"] as? Int
            node.state = state
            return node
        }
    }
}

// MARK: - 树构建

extension BrowserAccessibilityNode {
    /// 把扁平列表重建为树。
    ///
    /// 父节点必须排在子节点之前（页面脚本按文档序输出），否则该节点被当作根节点，
    /// 避免异常数据造成递归爆栈。
    static func buildTree(from nodes: [BrowserAccessibilityNode]) -> [BrowserAccessibilityNode] {
        var childIndices: [Int: [Int]] = [:]
        var roots: [Int] = []
        for (index, node) in nodes.enumerated() {
            if node.parentIndex >= 0 && node.parentIndex < index {
                childIndices[node.parentIndex, default: []].append(index)
            } else {
                roots.append(index)
            }
        }

        func build(_ index: Int) -> BrowserAccessibilityNode {
            var node = nodes[index]
            node.children = (childIndices[index] ?? []).map(build)
            return node
        }
        return roots.map(build)
    }

    /// 收集子树中的全部节点（含自身）。
    static func descendants(of node: BrowserAccessibilityNode) -> [BrowserAccessibilityNode] {
        [node] + node.children.flatMap(descendants(of:))
    }
}

// MARK: - 渲染

extension BrowserAccessibilityNode {
    /// 转义进入逐行文本协议的页面字段。
    ///
    /// 页面提供的字段未转义时，换行会伪造出额外的节点行，
    /// 引号与反斜杠会模糊 name/value 的字段边界。
    static func escapeProtocolField(_ value: String) -> String {
        var out = ""
        out.reserveCapacity(value.count)
        for character in value {
            switch character {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\r": out += "\\r"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            default: out.append(character)
            }
        }
        return out
    }

    /// 渲染为单行文本记录，格式为 `@ref role "name" [flags]`。
    ///
    /// 过滤与未过滤快照共用此实现，保证同一节点只有一种序列化结果。
    func renderLine() -> String {
        var line = "@\(ref) \(Self.escapeProtocolField(role))"
        line += " \"\(Self.escapeProtocolField(displayName))\""
        let flags = state.flags
        if !flags.isEmpty {
            line += " [\(flags.joined(separator: " "))]"
        }
        if let value {
            line += " value=\"\(Self.escapeProtocolField(value))\""
        }
        if let href {
            line += " → \(Self.escapeProtocolField(href))"
        }
        return line
    }

    /// 渲染为带缩进的文本行，格式为 `@ref role "name" [flags]`。
    ///
    /// 缩进深度体现页面结构，让 LLM 能区分「主内容区里的按钮」和「页脚里的链接」。
    static func renderLines(_ nodes: [BrowserAccessibilityNode], depth: Int = 0) -> [String] {
        var lines: [String] = []
        for node in nodes {
            lines.append(String(repeating: "  ", count: depth) + node.renderLine())
            lines.append(contentsOf: renderLines(node.children, depth: depth + 1))
        }
        return lines
    }
}
