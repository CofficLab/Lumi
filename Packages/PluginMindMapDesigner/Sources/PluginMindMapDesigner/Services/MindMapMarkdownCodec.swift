import Foundation

/// Markdown 大纲 ↔ MindMap 互相转换。
///
/// 采用「无序列表缩进」表示层级（与多数大纲工具、markmap 的列表输入兼容），
/// 例如：
///
/// ```
/// 中心主题
///  - 一级分支 A
///    - 二级分支 A1
///    - 二级分支 A2
///  - 一级分支 B
/// ```
///
/// 首个非空非列表行（或第 0 层列表项）作为根节点。
public enum MindMapMarkdownCodec {
    /// 把思维导图编码为 Markdown 大纲文本。
    public static func encode(_ map: MindMap) -> String {
        guard let root = map.root else { return map.title }
        var lines: [String] = []
        lines.append("# \(map.title)")
        encode(node: root, map: map, indent: 0, into: &lines, isRoot: true)
        return lines.joined(separator: "\n")
    }

    private static func encode(
        node: MindMapNode,
        map: MindMap,
        indent: Int,
        into lines: inout [String],
        isRoot: Bool
    ) {
        if !isRoot {
            let prefix = String(repeating: "  ", count: indent) + "- "
            lines.append("\(prefix)\(node.text)")
        }
        for child in map.children(of: node.id) {
            encode(node: child, map: map, indent: isRoot ? 0 : indent + 1, into: &lines, isRoot: false)
        }
    }

    /// 把 Markdown 大纲文本解析为思维导图。
    public static func decode(markdown: String, title: String?, direction: MindMapLayoutDirection = .bilateral) -> MindMap {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        var nodes: [MindMapNode] = []
        var rootText = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Mind Map"

        // 每一层缩进对应的最新节点 id（stack[index] = 该缩进层最近的节点）。
        var stack: [String] = []
        var rootId: String?

        for raw in lines {
            let (indent, content) = parseListItem(raw)
            guard !content.isEmpty else { continue }

            // 第一个无缩进的标题行（# 开头）作为文档标题而非节点。
            if indent == -1 {
                if nodes.isEmpty, content.hasPrefix("#") {
                    let trimmed = content.drop(while: { $0 == "#" || $0 == " " })
                    if !trimmed.isEmpty {
                        rootText = String(trimmed)
                    }
                    continue
                }
                // 顶层裸文本：作为根节点
                if rootId == nil {
                    let node = MindMapNode(parentId: nil, text: content)
                    rootId = node.id
                    nodes.append(node)
                    stack = [node.id]
                    continue
                }
            }

            // 列表项：缩进决定父节点。
            let parentId: String?
            if rootId == nil {
                // 首项即列表：创建一个根承载标题，再挂当前项。
                let root = MindMapNode(parentId: nil, text: rootText)
                rootId = root.id
                nodes.append(root)
                stack = [root.id]
            }
            // 规整 stack：保留 [0...indent]，超出则截断。
            if indent == 0 {
                parentId = rootId
                stack = [rootId!]
            } else {
                let safeIndex = min(indent, stack.count - 1)
                parentId = stack[safeIndex]
                // stack 裁剪到 safeIndex，再追加当前
                if safeIndex < stack.count - 1 {
                    stack = Array(stack[0...safeIndex])
                }
            }

            let node = MindMapNode(parentId: parentId, text: content)
            nodes.append(node)
            stack.append(node.id)
        }

        // 容错：若没有任何节点，构造一个空根。
        if nodes.isEmpty {
            let root = MindMapNode(parentId: nil, text: rootText.isEmpty ? "Mind Map" : rootText)
            nodes.append(root)
        }

        return MindMap(
            title: rootText.isEmpty ? "Mind Map" : rootText,
            nodes: nodes,
            layoutDirection: direction
        )
    }

    /// 解析一行，返回 (缩进层级, 内容)。非列表行返回 (-1, 去空格内容)。
    private static func parseListItem(_ line: String) -> (indent: Int, content: String) {
        var spaces = 0
        for ch in line {
            if ch == " " {
                spaces += 1
            } else if ch == "\t" {
                spaces += 4
            } else {
                break
            }
        }
        let rest = line.drop(while: { $0 == " " || $0 == "\t" })
        // 列表标记：- + * 或 数字.
        if rest.hasPrefix("- ") || rest.hasPrefix("+ ") || rest.hasPrefix("* ") {
            let content = rest.dropFirst(2).trimmingCharacters(in: .whitespaces)
            return (max(spaces / 2, 0), content)
        }
        if let match = rest.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            let content = rest[match.upperBound...].trimmingCharacters(in: .whitespaces)
            return (max(spaces / 2, 0), content)
        }
        return (-1, rest.trimmingCharacters(in: .whitespaces))
    }
}
