import Foundation

/// Emmet 缩写展开结果
struct EmmetExpansion: Equatable, Sendable {
    /// 展开后的 HTML 文本
    let text: String
    /// 光标应放置的位置偏移量（相对于展开文本）
    let cursorOffset: Int
    /// 原始缩写
    let abbreviation: String
}

/// Emmet 解析与生成引擎
///
/// 本地实现 Emmet 缩写解析，支持 HTML/JSX 模式。
/// 不依赖 LSP，实现毫秒级响应。
enum EmmetEngine {
    // MARK: - 公共接口

    /// 尝试解析并展开 Emmet 缩写
    ///
    /// - Parameters:
    ///   - abbreviation: Emmet 缩写字符串 (如 `div.box>ul>li.item$*3`)
    ///   - syntax: 语法模式
    /// - Returns: 展开结果，如果解析失败返回 nil
    static func expand(_ abbreviation: String, syntax: EmmetSyntax = .html) -> EmmetExpansion? {
        let trimmed = abbreviation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var parser = EmmetParser(input: trimmed)
        guard let rootNode = parser.parse() else { return nil }

        let generator = EmmetGenerator(syntax: syntax)
        return generator.generate(from: rootNode, abbreviation: trimmed)
    }

    /// 判断给定文本是否可能是有效的 Emmet 缩写
    static func isValidAbbreviation(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // 必须包含至少一个字母或合法字符
        let validChars = CharacterSet.letters.union(CharacterSet(charactersIn: ".#*[]:{}()>+-^$@/"))
        return trimmed.unicodeScalars.allSatisfy { validChars.contains($0) }
    }
}

// MARK: - Emmet 语法模式

enum EmmetSyntax: Sendable {
    case html
    case xhtml
    case jsx

    var selfClosingSuffix: String {
        switch self {
        case .html: return ""
        case .xhtml, .jsx: return " /"
        }
    }
}

// MARK: - AST 节点

/// Emmet 缩写解析后的抽象语法树节点
struct EmmetNode: Equatable {
    /// 标签名
    var tagName: String = "div"
    /// CSS 类名
    var classNames: [String] = []
    /// ID
    var id: String?
    /// 自定义属性
    var attributes: [String: String] = [:]
    /// 文本内容
    var textContent: String?
    /// 子节点
    var children: [EmmetNode] = []
    /// 重复次数
    var repeatCount: Int = 1
    /// 重复计数器变量 (如 `$` -> 1, 2, 3)
    var hasCounter: Bool = false
    /// 相邻兄弟节点
    var siblings: [EmmetNode] = []

    /// 是否为空标签（无子节点和无文本）
    var isEmpty: Bool {
        children.isEmpty && textContent == nil && siblings.isEmpty
    }
}

// MARK: - 解析器

/// Emmet 缩写字符串解析器
///
/// 将缩写字符串解析为抽象语法树。
/// 支持的语法：
/// - 元素: `div`, `span`, `p`
/// - 类: `.class`, `.class1.class2`
/// - ID: `#myid`
/// - 子级: `>`
/// - 兄弟: `+`
/// - 上升: `^`
/// - 重复: `*3`
/// - 分组: `(div>p)+span`
/// - 文本: `{Hello}`
/// - 属性: `[attr=value]`
/// - 计数: `$`
private struct EmmetParser {
    let input: String
    private var index: String.Index

    init(input: String) {
        self.input = input
        self.index = input.startIndex
    }

    mutating func parse() -> EmmetNode? {
        guard !input.isEmpty else { return nil }
        let node = parseExpression()
        return index >= input.endIndex ? node : nil
    }

    // MARK: - 解析方法

    private mutating func parseExpression() -> EmmetNode {
        var node = parseElement()

        while index < input.endIndex {
            let char = input[index]

            if char == "+" {
                advance()
                let sibling = parseElement()
                node.siblings.append(sibling)
            } else if char == ">" {
                advance()
                let child = parseElement()
                node.children.append(child)
                // 后续的子元素应该添加到最后一个子节点上
                if let lastChild = node.children.last {
                    var updatedChild = lastChild
                    while index < input.endIndex, input[index] == ">" {
                        advance()
                        let nextChild = parseElement()
                        updatedChild.children.append(nextChild)
                    }
                    node.children[node.children.count - 1] = updatedChild
                }
            } else if char == "^" {
                // 上升 - 由调用者处理
                break
            } else {
                break
            }
        }

        return node
    }

    private mutating func parseElement() -> EmmetNode {
        var node = EmmetNode()

        // 解析分组
        if index < input.endIndex, input[index] == "(" {
            advance() // 跳过 (
            node = parseExpression()
            if index < input.endIndex, input[index] == ")" {
                advance() // 跳过 )
            }
        } else {
            // 解析标签名
            node.tagName = parseTagName()
        }

        // 解析类和 ID
        parseClassAndId(into: &node)

        // 解析属性
        parseAttributes(into: &node)

        // 解析文本内容
        parseTextContent(into: &node)

        // 解析重复
        parseRepeat(into: &node)

        return node
    }

    private mutating func parseTagName() -> String {
        var name = ""
        while index < input.endIndex {
            let char = input[index]
            if char == "." || char == "#" || char == ">" || char == "+" ||
                char == "^" || char == "*" || char == "[" || char == "{" || char == "(" || char == ")" {
                break
            }
            name.append(char)
            advance()
        }
        return name.isEmpty ? "div" : name
    }

    private mutating func parseClassAndId(into node: inout EmmetNode) {
        while index < input.endIndex {
            let char = input[index]

            if char == "." {
                advance()
                var className = ""
                while index < input.endIndex {
                    let c = input[index]
                    if c == "." || c == "#" || c == ">" || c == "+" || c == "^" ||
                        c == "*" || c == "[" || c == "{" || c == "(" || c == ")" {
                        break
                    }
                    className.append(c)
                    advance()
                }
                if !className.isEmpty {
                    node.classNames.append(className)
                }
            } else if char == "#" {
                advance()
                var id = ""
                while index < input.endIndex {
                    let c = input[index]
                    if c == "." || c == "#" || c == ">" || c == "+" || c == "^" ||
                        c == "*" || c == "[" || c == "{" || c == "(" || c == ")" {
                        break
                    }
                    id.append(c)
                    advance()
                }
                if !id.isEmpty {
                    node.id = id
                }
            } else {
                break
            }
        }
    }

    private mutating func parseAttributes(into node: inout EmmetNode) {
        while index < input.endIndex, input[index] == "[" {
            advance() // 跳过 [
            var key = ""
            var value = ""
            var parsingKey = true

            while index < input.endIndex, input[index] != "]" {
                let char = input[index]
                if char == "=" {
                    parsingKey = false
                    advance()
                    continue
                }

                if parsingKey {
                    key.append(char)
                } else {
                    value.append(char)
                }
                advance()
            }

            if index < input.endIndex {
                advance() // 跳过 ]
            }

            if !key.isEmpty {
                node.attributes[key] = value
            }
        }
    }

    private mutating func parseTextContent(into node: inout EmmetNode) {
        while index < input.endIndex, input[index] == "{" {
            advance() // 跳过 {
            var text = ""
            while index < input.endIndex, input[index] != "}" {
                text.append(input[index])
                advance()
            }
            if index < input.endIndex {
                advance() // 跳过 }
            }
            node.textContent = text
        }
    }

    private mutating func parseRepeat(into node: inout EmmetNode) {
        if index < input.endIndex, input[index] == "*" {
            advance() // 跳过 *
            var countStr = ""
            while index < input.endIndex, input[index].isNumber {
                countStr.append(input[index])
                advance()
            }
            if let count = Int(countStr), count > 0 {
                node.repeatCount = count
            }
        }

        // 检测计数器变量 $
        if index < input.endIndex, input[index] == "$" {
            node.hasCounter = true
            advance()
        }
    }

    private mutating func advance() {
        if index < input.endIndex {
            index = input.index(after: index)
        }
    }
}

// MARK: - 生成器

/// 将 Emmet AST 生成为 HTML 文本
private struct EmmetGenerator {
    let syntax: EmmetSyntax
    private let indent: String = "  "

    init(syntax: EmmetSyntax) {
        self.syntax = syntax
    }

    func generate(from node: EmmetNode, abbreviation: String) -> EmmetExpansion {
        let result = generateNode(node, level: 0, counter: 1, hasCounter: node.hasCounter)
        return EmmetExpansion(text: result.text, cursorOffset: result.cursorOffset, abbreviation: abbreviation)
    }

    private func generateNode(_ node: EmmetNode, level: Int, counter: Int, hasCounter: Bool) -> (text: String, cursorOffset: Int) {
        let currentIndent = String(repeating: indent, count: level)

        var parts: [String] = []
        var cursorOffset = -1

        // 处理重复
        if node.repeatCount > 1 {
            var repeatedParts: [String] = []
            for i in 1...node.repeatCount {
                let repeatedCounter = hasCounter ? i : counter
                var clonedNode = node
                clonedNode.repeatCount = 1
                clonedNode.hasCounter = false
                let result = generateSingleNode(clonedNode, level: level, counter: repeatedCounter, hasCounter: hasCounter)
                repeatedParts.append(result.text)

                if cursorOffset < 0, result.cursorOffset >= 0 {
                    // 在最后一个重复项中放置光标
                    if i == node.repeatCount {
                        cursorOffset = result.cursorOffset
                    } else {
                        cursorOffset = -1 // 重置，最后一个才会设置
                    }
                }
            }
            let joinedText = repeatedParts.joined(separator: "\n")
            return (joinedText, cursorOffset)
        }

        let result = generateSingleNode(node, level: level, counter: counter, hasCounter: hasCounter)
        return result
    }

    private func generateSingleNode(_ node: EmmetNode, level: Int, counter: Int, hasCounter: Bool) -> (text: String, cursorOffset: Int) {
        let currentIndent = String(repeating: indent, count: level)
        var cursorOffset = -1

        // 替换计数器
        var tagName = node.tagName
        if hasCounter {
            let counterStr = String(counter)
            tagName = tagName.replacingOccurrences(of: "$", with: counterStr)
        }

        // 构建属性字符串
        var attrs = buildAttributes(node: node, counter: counter, hasCounter: hasCounter)

        // 构建开标签
        var openingTag = "<\(tagName)"
        if !attrs.isEmpty {
            openingTag += " \(attrs)"
        }

        // 检查是否为自闭合标签
        let voidElements = HTMLKnowledgeBase.voidElements
        let isVoid = voidElements.contains(tagName.lowercased())

        var resultText: String
        var localCursorOffset = -1

        if isVoid {
            if syntax == .xhtml || syntax == .jsx {
                openingTag += " />"
            } else {
                openingTag += ">"
            }
            resultText = openingTag
            localCursorOffset = openingTag.utf16.count
        } else if node.children.isEmpty, node.siblings.isEmpty, node.textContent == nil {
            // 空元素 - 光标放在标签中间
            let closingTag = "</\(tagName)>"
            resultText = openingTag + closingTag
            localCursorOffset = openingTag.utf16.count
        } else {
            openingTag += ">"

            var bodyParts: [String] = []

            // 文本内容
            if let text = node.textContent {
                bodyParts.append(text)
                localCursorOffset = openingTag.utf16.count + text.utf16.count
            }

            // 子节点
            for child in node.children {
                let childResult = generateNode(child, level: level + 1, counter: counter, hasCounter: child.hasCounter)
                if level == 0 {
                    bodyParts.append("\n" + childResult.text)
                } else {
                    bodyParts.append("\n" + String(repeating: indent, count: level + 1) + childResult.text)
                }
                if childResult.cursorOffset >= 0, localCursorOffset < 0 {
                    localCursorOffset = openingTag.utf16.count + bodyParts.joined().utf16.count - (childResult.text.utf16.count - childResult.cursorOffset)
                }
            }

            // 兄弟节点
            for sibling in node.siblings {
                let siblingResult = generateNode(sibling, level: level, counter: counter, hasCounter: sibling.hasCounter)
                let prefix = "\n" + (level > 0 ? String(repeating: indent, count: level) : "")
                bodyParts.append(prefix + siblingResult.text)
            }

            let closingTag = "</\(tagName)>"
            let body = bodyParts.joined()

            if body.isEmpty {
                resultText = openingTag + closingTag
                localCursorOffset = openingTag.utf16.count
            } else {
                resultText = openingTag + body + "\n" + currentIndent + closingTag
                if localCursorOffset < 0 {
                    localCursorOffset = openingTag.utf16.count
                }
            }
        }

        return (resultText, localCursorOffset)
    }

    private func buildAttributes(node: EmmetNode, counter: Int, hasCounter: Bool) -> String {
        var parts: [String] = []

        // 类名
        if !node.classNames.isEmpty {
            var classes = node.classNames.map {
                hasCounter ? $0.replacingOccurrences(of: "$", with: String(counter)) : $0
            }
            parts.append("class=\"\(classes.joined(separator: " "))\"")
        }

        // ID
        if let id = node.id {
            parts.append("id=\"\(id)\"")
        }

        // 自定义属性
        for (key, value) in node.attributes.sorted(by: { $0.key < $1.key }) {
            if value.isEmpty {
                parts.append(key)
            } else {
                parts.append("\(key)=\"\(value)\"")
            }
        }

        return parts.joined(separator: " ")
    }
}
