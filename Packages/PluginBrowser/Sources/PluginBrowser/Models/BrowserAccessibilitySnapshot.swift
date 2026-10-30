import Foundation

/// 一次可访问性快照的结果。
struct BrowserAccessibilitySnapshot: Sendable {
    var pageTitle: String
    var pageURL: String
    var roots: [BrowserAccessibilityNode]
    var totalNodeCount: Int

    /// 过滤后用于渲染的节点集合。
    ///
    /// - Parameter interactiveOnly: 只保留可交互角色（按钮、链接、输入框…），
    ///   适合页面元素很多时快速定位目标。
    func filteredNodes(interactiveOnly: Bool) -> [BrowserAccessibilityNode] {
        guard interactiveOnly else { return roots }
        return prune(roots)
    }

    /// 递归剔除不可交互的叶子节点，但保留仍有可交互后代的分支。
    private func prune(_ nodes: [BrowserAccessibilityNode]) -> [BrowserAccessibilityNode] {
        var result: [BrowserAccessibilityNode] = []
        for node in nodes {
            let prunedChildren = prune(node.children)
            if node.isInteractive || !prunedChildren.isEmpty {
                var copy = node
                copy.children = prunedChildren
                result.append(copy)
            }
        }
        return result
    }

    /// 渲染为文本快照。
    ///
    /// 结构示例：
    /// ```
    /// @lumi-3 button "登录" [disabled]
    /// @lumi-7 textbox "邮箱" value="a@b.com"
    /// ```
    func render(interactiveOnly: Bool, maxLines: Int = 400) -> String {
        let nodes = filteredNodes(interactiveOnly: interactiveOnly)
        var lines = BrowserAccessibilityNode.renderLines(nodes)
        let truncated = lines.count > maxLines
        if truncated { lines = Array(lines.prefix(maxLines)) }
        return lines.joined(separator: "\n") + (truncated ? "\n… (snapshot truncated)" : "")
    }
}
