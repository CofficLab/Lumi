import Foundation
import AppKit
import SwiftUI
import Combine
import CodeEditSourceEditor
import CodeEditTextView
import CodeEditLanguages
import SwiftTreeSitter
import LanguageServerProtocol
import MagicAlert
import os
import MagicKit

/// Jump-to-definition delegate
/// 基于 Tree-Sitter AST 实现文件内跳转（Cmd+Click）
/// 
/// 工作原理：
/// 1. 用户按住 Cmd 并点击标识符
/// 2. CodeEditSourceEditor 的 JumpToDefinitionModel 检测到交互
/// 3. 调用此 Delegate 的 queryLinks 方法
/// 4. 此方法通过 AST 或正则查找定义位置
/// 5. 引擎自动执行跳转或显示多定义弹窗
@preconcurrency
final class EditorJumpToDefinitionDelegate: ObservableObject, JumpToDefinitionDelegate, SuperLog {
    nonisolated static let emoji = "🔗"
    
    weak var treeSitterClient: TreeSitterClient?
    weak var textStorage: NSTextStorage?
    weak var lspClient: (any EditorLSPClient)?
    weak var textViewController: TextViewController?
    var currentFileURLProvider: (() -> URL?)?
    var onOpenExternalDefinition: ((URL, CursorPosition) -> Void)?
    private let requestGeneration = RequestGeneration()
    
    // MARK: - JumpToDefinitionDelegate
    
    /// 查询定义链接 - 当用户 Cmd+Click 时，引擎调用此方法查找目标
    func queryLinks(forRange range: NSRange, textView: TextViewController) async -> [JumpToDefinitionLink]? {
        guard let textStorage = textStorage else { return nil }
        let generation = requestGeneration.next()
        
        let content = textStorage.string
        let word = (content as NSString).substring(with: range)
        
        // 过滤无效输入
        guard !word.isEmpty, word.rangeOfCharacter(from: .alphanumerics) != nil else {
            return nil
        }
        
        if EditorPlugin.verbose {
            EditorPlugin.logger.debug("\(self.t)跳转到定义: '\(word)' 位置=\(range.location)")
        }

        if let includeLink = findXCConfigIncludeLink(forRange: range, content: content) {
            return [includeLink]
        }

        if let packageLink = findSwiftPackageDependencyLink(forRange: range, content: content) {
            return [packageLink]
        }

        // 0. 优先：通过 LSP 查询定义（支持跨文件）
        if let link = await findDefinitionViaLSP(
            word: word,
            cursorRange: range,
            content: content
        ) {
            guard requestGeneration.isCurrent(generation) else { return nil }
            if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(self.t)LSP 匹配: '\(word)'")
            }
            return [link]
        }
        
        // 1. 优先：通过 AST 查找定义（精确）
        if let definitionRange = await findDefinitionViaAST(
            word: word,
            cursorRange: range,
            content: content
        ) {
            guard requestGeneration.isCurrent(generation) else { return nil }
            let position = CursorPosition(range: definitionRange)
            if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(self.t)AST 匹配: '\(word)' -> \(definitionRange.location)")
            }
            return [createLink(for: word, targetRange: position, content: content)]
        }
        
        // 2. 回退：通过正则匹配（快速但不够精确）
        if let fallbackRange = findDefinitionViaRegex(
            word: word,
            cursorRange: range,
            content: content
        ) {
            guard requestGeneration.isCurrent(generation) else { return nil }
            let position = CursorPosition(range: fallbackRange)
            if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(self.t)正则匹配: '\(word)' -> \(fallbackRange.location)")
            }
            return [createLink(for: word, targetRange: position, content: content)]
        }
        
        if EditorPlugin.verbose {
            EditorPlugin.logger.debug("\(self.t)未找到定义: '\(word)'")
        }
        return nil
    }
    
    /// 打开链接（本地跳转由引擎自动处理，这里仅记录日志）
    func openLink(link: JumpToDefinitionLink) {
        if EditorPlugin.verbose {
            EditorPlugin.logger.debug("\(self.t)打开链接: \(link.label) -> \(link.url?.absoluteString ?? "本地")")
        }
        guard let url = link.url else { return }
        onOpenExternalDefinition?(url, link.targetRange)
    }
    
    /// 右键菜单可直接调用此方法复用完整跳转流程
    @MainActor
    func performGoToDefinition(forRange range: NSRange) async {
        await performGoToNavigation(forRange: range, kind: .definition, fallbackToAST: true, fallbackToRegex: true)
    }

    /// 跳转到声明（仅 LSP）
    @MainActor
    func performGoToDeclaration(forRange range: NSRange) async {
        await performGoToNavigation(forRange: range, kind: .declaration, fallbackToAST: false, fallbackToRegex: false)
    }

    /// 跳转到类型定义（仅 LSP）
    @MainActor
    func performGoToTypeDefinition(forRange range: NSRange) async {
        await performGoToNavigation(forRange: range, kind: .typeDefinition, fallbackToAST: false, fallbackToRegex: false)
    }

    /// 跳转到实现（仅 LSP）
    @MainActor
    func performGoToImplementation(forRange range: NSRange) async {
        await performGoToNavigation(forRange: range, kind: .implementation, fallbackToAST: false, fallbackToRegex: false)
    }

    /// 通用 LSP 导航跳转方法
    @MainActor
    private func performGoToNavigation(
        forRange range: NSRange,
        kind: LSPNavigationKind,
        fallbackToAST: Bool,
        fallbackToRegex: Bool
    ) async {
        guard let ts = textStorage, let controller = textViewController else { return }
        let generation = requestGeneration.next()
        let content = ts.string
        let word = (content as NSString).substring(with: range)
        if let preflightMessage = navigationPreflightFailureMessage(kind: kind, symbolName: word) {
            guard requestGeneration.isCurrent(generation) else { return }
            NSSound.beep()
            alert_warning(preflightMessage, duration: 2.4)
            return
        }

        if kind == .definition,
           let includeLink = findXCConfigIncludeLink(forRange: range, content: content) {
            guard requestGeneration.isCurrent(generation) else { return }
            openNavigationLink(includeLink, textStorage: ts, controller: controller)
            return
        }

        if kind == .definition,
           let packageLink = findSwiftPackageDependencyLink(forRange: range, content: content) {
            guard requestGeneration.isCurrent(generation) else { return }
            openNavigationLink(packageLink, textStorage: ts, controller: controller)
            return
        }

        // 1. 优先通过 LSP 查找
        if let link = await findLocationViaLSP(
            kind: kind,
            word: word,
            cursorRange: range,
            content: content
        ) {
            guard requestGeneration.isCurrent(generation) else { return }
            openNavigationLink(link, textStorage: ts, controller: controller)
            return
        }

        // 2. 回退：通过 AST（仅 Definition 支持）
        if fallbackToAST,
           let definitionRange = await findDefinitionViaAST(
               word: word,
               cursorRange: range,
               content: content
           ) {
            guard requestGeneration.isCurrent(generation) else { return }
            let position = CursorPosition(range: definitionRange)
            let link = createLink(for: word, targetRange: position, content: content)
            openNavigationLink(link, textStorage: ts, controller: controller)
            return
        }

        // 3. 回退：通过正则（仅 Definition 支持）
        if fallbackToRegex,
           let fallbackRange = findDefinitionViaRegex(
               word: word,
               cursorRange: range,
               content: content
           ) {
            guard requestGeneration.isCurrent(generation) else { return }
            let position = CursorPosition(range: fallbackRange)
            let link = createLink(for: word, targetRange: position, content: content)
            openNavigationLink(link, textStorage: ts, controller: controller)
            return
        }

        // 未找到目标
        NSSound.beep()
        let fallbackMessage = kind.toastNotFound
        let message = navigationFailureMessage(kind: kind, symbolName: word)
        if message == fallbackMessage {
            alert_info(message, duration: 1.5)
        } else {
            alert_warning(message, duration: 2.4)
        }
    }

    /// 打开导航链接（同文件 / 跨文件）
    @MainActor
    private func openNavigationLink(_ link: JumpToDefinitionLink, textStorage: NSTextStorage, controller: TextViewController) {
        if let url = link.url {
            guard url.isFileURL else {
                NSWorkspace.shared.open(url)
                return
            }
            // 跨文件跳转
            onOpenExternalDefinition?(url, link.targetRange)
        } else {
            // 同文件跳转
            let targetNSRange = link.targetRange.range
            var selectionRange = targetNSRange
            if targetNSRange.length == 0,
               let swiftRange = Range(targetNSRange, in: textStorage.string) {
                let lineRange = textStorage.string.lineRange(for: swiftRange)
                selectionRange = NSRange(lineRange, in: textStorage.string)
            }
            controller.textView.selectionManager.setSelectedRange(selectionRange)
            controller.textView.scrollSelectionToVisible()
        }
    }

    // MARK: - LSP 查找

    private func findXCConfigIncludeLink(
        forRange range: NSRange,
        content: String
    ) -> JumpToDefinitionLink? {
        guard let currentFileURL = currentFileURLProvider?(),
              currentFileURL.pathExtension.lowercased() == "xcconfig",
              let directive = XCConfigSyntax.includeDirective(at: range.location, in: content),
              let targetURL = XCConfigSyntax.resolveIncludedFileURL(
                for: directive,
                currentFileURL: currentFileURL
              ) else {
            return nil
        }

        return JumpToDefinitionLink(
            url: targetURL,
            targetRange: CursorPosition(start: .init(line: 1, column: 1), end: nil),
            typeName: directive.path,
            sourcePreview: targetURL.lastPathComponent,
            documentation: nil,
            image: Image(systemName: "link"),
            imageColor: Color(NSColor.systemPurple)
        )
    }

    private func findSwiftPackageDependencyLink(
        forRange range: NSRange,
        content: String
    ) -> JumpToDefinitionLink? {
        guard currentFileURLProvider?()?.lastPathComponent == "Package.swift",
              let dependency = PackageManifestSyntax.dependencyLink(at: range.location, in: content) else {
            return nil
        }

        return JumpToDefinitionLink(
            url: dependency.url,
            targetRange: CursorPosition(start: .init(line: 1, column: 1), end: nil),
            typeName: dependency.rawURL,
            sourcePreview: dependency.url.host ?? dependency.rawURL,
            documentation: nil,
            image: Image(systemName: "safari"),
            imageColor: Color(NSColor.systemBlue)
        )
    }

    private func findDefinitionViaLSP(
        word: String,
        cursorRange: NSRange,
        content: String
    ) async -> JumpToDefinitionLink? {
        return await findLocationViaLSP(
            kind: .definition,
            word: word,
            cursorRange: cursorRange,
            content: content
        )
    }

    /// 通过 LSP 查找声明位置
    func findDeclarationLocation(
        word: String,
        cursorRange: NSRange,
        content: String
    ) async -> JumpToDefinitionLink? {
        return await findLocationViaLSP(
            kind: .declaration,
            word: word,
            cursorRange: cursorRange,
            content: content
        )
    }

    /// 通过 LSP 查找类型定义位置
    func findTypeDefinitionLocation(
        word: String,
        cursorRange: NSRange,
        content: String
    ) async -> JumpToDefinitionLink? {
        return await findLocationViaLSP(
            kind: .typeDefinition,
            word: word,
            cursorRange: cursorRange,
            content: content
        )
    }

    /// 通过 LSP 查找实现位置
    func findImplementationLocation(
        word: String,
        cursorRange: NSRange,
        content: String
    ) async -> JumpToDefinitionLink? {
        return await findLocationViaLSP(
            kind: .implementation,
            word: word,
            cursorRange: cursorRange,
            content: content
        )
    }

    /// LSP 导航位置查找类型
    private enum LSPNavigationKind {
        case definition
        case declaration
        case typeDefinition
        case implementation

        var toastFinding: String {
            switch self {
            case .definition: return String(localized: "Finding definition...", table: "LumiEditor")
            case .declaration: return String(localized: "Finding declaration...", table: "LumiEditor")
            case .typeDefinition: return String(localized: "Finding type definition...", table: "LumiEditor")
            case .implementation: return String(localized: "Finding implementation...", table: "LumiEditor")
            }
        }

        var toastNotFound: String {
            switch self {
            case .definition: return String(localized: "No definition found", table: "LumiEditor")
            case .declaration: return String(localized: "No declaration found", table: "LumiEditor")
            case .typeDefinition: return String(localized: "No type definition found", table: "LumiEditor")
            case .implementation: return String(localized: "No implementation found", table: "LumiEditor")
            }
        }
    }

    @MainActor
    private func navigationFailureMessage(kind: LSPNavigationKind, symbolName: String) -> String {
        XcodeSemanticAvailability.missingResultMessage(
            uri: currentFileURLProvider?()?.absoluteString,
            operation: operationName(for: kind),
            symbolName: symbolName
        ) ?? kind.toastNotFound
    }

    @MainActor
    private func navigationPreflightFailureMessage(kind: LSPNavigationKind, symbolName: String) -> String? {
        XcodeSemanticAvailability.preflightMessage(
            uri: currentFileURLProvider?()?.absoluteString,
            operation: operationName(for: kind),
            symbolName: symbolName,
            strength: .hard
        )
    }

    @MainActor
    private func operationName(for kind: LSPNavigationKind) -> String {
        switch kind {
        case .definition:
            return "跳转到定义"
        case .declaration:
            return "跳转到声明"
        case .typeDefinition:
            return "跳转到类型定义"
        case .implementation:
            return "跳转到实现"
        }
    }

    @MainActor
    private func findLocationViaLSP(
        kind: LSPNavigationKind,
        word: String,
        cursorRange: NSRange,
        content: String
    ) async -> JumpToDefinitionLink? {
        guard let lspClient else {
            EditorPlugin.logger.warning("\(self.t)LSP 跳转取消: lspClient 不存在, kind=\(String(describing: kind), privacy: .public), word=\(word, privacy: .public)")
            return nil
        }

        guard let lspPosition = Self.lspPosition(utf16Offset: cursorRange.location, in: content) else {
            EditorPlugin.logger.warning("\(self.t)LSP 跳转取消: 无法换算 LSP 位置, kind=\(String(describing: kind), privacy: .public), word=\(word, privacy: .public), range=\(cursorRange.location)-\(cursorRange.length)")
            return nil
        }
        let currentURI = currentFileURLProvider?()?.absoluteString
        EditorPlugin.logger.info(
            "\(self.t)LSP 跳转请求: kind=\(String(describing: kind), privacy: .public), word=\(word, privacy: .public), currentURI=\(currentURI ?? "<nil>", privacy: .public), utf16Offset=\(cursorRange.location), lspLine=\(lspPosition.line), lspCharacter=\(lspPosition.character)"
        )

        let location: Location?
        switch kind {
        case .definition:
            location = await lspClient.requestDefinition(
                line: lspPosition.line,
                character: lspPosition.character
            )
        case .declaration:
            location = await lspClient.requestDeclaration(
                line: lspPosition.line,
                character: lspPosition.character
            )
        case .typeDefinition:
            location = await lspClient.requestTypeDefinition(
                line: lspPosition.line,
                character: lspPosition.character
            )
        case .implementation:
            location = await lspClient.requestImplementation(
                line: lspPosition.line,
                character: lspPosition.character
            )
        }

        guard let location else {
            EditorPlugin.logger.warning(
                "\(self.t)LSP 跳转无结果: kind=\(String(describing: kind), privacy: .public), word=\(word, privacy: .public), currentURI=\(currentURI ?? "<nil>", privacy: .public), lspLine=\(lspPosition.line), lspCharacter=\(lspPosition.character)"
            )
            return nil
        }
        EditorPlugin.logger.info(
            "\(self.t)LSP 跳转命中: kind=\(String(describing: kind), privacy: .public), word=\(word, privacy: .public), targetURI=\(location.uri, privacy: .public), start=\(location.range.start.line):\(location.range.start.character), end=\(location.range.end.line):\(location.range.end.character)"
        )

        let isSameFile = currentURI == location.uri

        if isSameFile,
           let targetRange = Self.nsRange(from: location.range, in: content) {
            return createLink(
                for: word,
                targetRange: CursorPosition(range: NSRange(location: targetRange.location, length: 0)),
                content: content
            )
        }

        guard let url = URL(string: location.uri) else { return nil }
        let targetPosition = CursorPosition(
            start: CursorPosition.Position(
                line: Int(location.range.start.line) + 1,
                column: Int(location.range.start.character) + 1
            ),
            end: CursorPosition.Position(
                line: Int(location.range.end.line) + 1,
                column: Int(location.range.end.character) + 1
            )
        )
        let preview = Self.previewLine(from: url, at: location.range.start) ?? word

        return JumpToDefinitionLink(
            url: url,
            targetRange: targetPosition,
            typeName: word,
            sourcePreview: preview,
            documentation: nil,
            image: imageForNavigationKind(kind),
            imageColor: Color(NSColor.systemBlue)
        )
    }

    private func imageForNavigationKind(_ kind: LSPNavigationKind) -> Image {
        switch kind {
        case .definition: return Image(systemName: "arrow.right.square.fill")
        case .declaration: return Image(systemName: "doc.badge.plus.fill")
        case .typeDefinition: return Image(systemName: "square.on.square.fill")
        case .implementation: return Image(systemName: "arrowtriangle.right.fill")
        }
    }
    
    // MARK: - AST 查找（核心逻辑）
    
    /// 通过 Tree-Sitter AST 查找定义
    private func findDefinitionViaAST(
        word: String,
        cursorRange: NSRange,
        content: String
    ) async -> NSRange? {
        guard let treeSitterClient = treeSitterClient else { return nil }
        
        do {
            // 获取当前光标位置的所有 AST 节点（可能有多层语言）
            let nodes = try await treeSitterClient.nodesAt(location: cursorRange.location)
            
            for nodeResult in nodes {
                if let defRange = searchNodeTree(
                    word: word,
                    cursorRange: cursorRange,
                    node: nodeResult.node,
                    content: content
                ) {
                    return defRange
                }
            }
        } catch {
            if EditorPlugin.verbose {
                EditorPlugin.logger.debug("\(self.t)AST 查询失败: \(error)")
            }
        }
        
        return nil
    }
    
    /// 递归搜索 AST 节点树
    private func searchNodeTree(
        word: String,
        cursorRange: NSRange,
        node: Node,
        content: String
    ) -> NSRange? {
        // 检查当前节点是否是定义
        if let defRange = checkDefinition(node: node, word: word, cursorRange: cursorRange, content: content) {
            return defRange
        }
        
        // 递归搜索子节点
        var cursor = node.treeCursor
        guard cursor.goToFirstChild() else { return nil }
        
        repeat {
            if let currentNode = cursor.currentNode {
                if let defRange = searchNodeTree(
                    word: word,
                    cursorRange: cursorRange,
                    node: currentNode,
                    content: content
                ) {
                    return defRange
                }
            }
        } while cursor.gotoNextSibling()
        
        return nil
    }
    
    /// 检查节点是否是目标定义
    private func checkDefinition(
        node: Node,
        word: String,
        cursorRange: NSRange,
        content: String
    ) -> NSRange? {
        guard let nodeType = node.nodeType else { return nil }
        
        // 定义节点类型关键词（跨语言通用）
        let definitionKeywords: Set<String> = [
            "function_definition", "method_definition", "class_definition",
            "struct_definition", "enum_definition", "interface_definition",
            "variable_declaration", "const_declaration", "let_declaration",
            "function_declaration", "declaration", "identifier",
            "property_declaration",
            "function_item", "struct_item", "enum_item", "impl_item",
            "type_declaration", "method_declaration", "constructor_declaration",
            "class_declaration", "struct_specifier", "class_specifier",
            "variable_declarator"
        ]
        
        // 检查是否是定义节点
        let isDefinition = definitionKeywords.contains { nodeType.contains($0) }
        guard isDefinition else { return nil }
        
        // 查找定义名称
        guard let nameRange = extractDefinitionName(node: node) else { return nil }
        let name = (content as NSString).substring(with: nameRange)
        
        // 匹配且不在光标位置
        if name == word && !cursorRange.intersects(nameRange) {
            return node.range
        }
        
        return nil
    }
    
    /// 从定义节点中提取名称范围
    private func extractDefinitionName(node: Node) -> NSRange? {
        // 优先查找 name 字段
        if let nameNode = node.child(byFieldName: "name") {
            return nameNode.range
        }
        
        // 其次查找 identifier 字段
        if let idNode = node.child(byFieldName: "identifier") {
            return idNode.range
        }
        
        // 搜索子树中的 identifier 节点
        return findIdentifierInTree(node: node)
    }
    
    /// 在节点子树中查找 identifier
    private func findIdentifierInTree(node: Node) -> NSRange? {
        var cursor = node.treeCursor
        guard cursor.goToFirstChild() else { return nil }
        
        repeat {
            if let currentNode = cursor.currentNode {
                if currentNode.nodeType == "identifier" {
                    return currentNode.range
                }
                // 递归搜索
                if currentNode.childCount > 0,
                   let found = findIdentifierInTree(node: currentNode) {
                    return found
                }
            }
        } while cursor.gotoNextSibling()
        
        return nil
    }
    
    // MARK: - 正则回退查找
    
    /// 通过正则回退查找定义（支持多语言）
    private func findDefinitionViaRegex(
        word: String,
        cursorRange: NSRange,
        content: String
    ) -> NSRange? {
        let escapedWord = NSRegularExpression.escapedPattern(for: word)
        
        // 多语言定义模式
        let patterns: [String] = [
            // 函数/方法/变量定义 (Swift/Kotlin/Java/C#/JS/TS/Python/Rust/Go)
            #"(?:func|fun|def|fn|function|void|int|string|let|var|const|class|struct|enum|interface|type)\s+\#(escapedWord)\b"#,
            // Rust pub fn
            #"pub\s+fn\s+\#(escapedWord)\b"#,
            // Go func with receiver
            #"func\s+\([^)]*\)\s+\#(escapedWord)\b"#,
            // C/C++ 函数
            #"(?:void|int|char|float|double|struct|class|enum)\s+\#(escapedWord)\s*\("#,
            // self.xxx / this.xxx 属性访问
            #"(?:self|this)\.\#(escapedWord)\b"#
        ]
        
        let nsContent = content as NSString
        let searchRange = NSRange(location: 0, length: min(cursorRange.location, nsContent.length))
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            
            if let match = regex.firstMatch(in: content, options: [], range: searchRange),
               match.range.length > 0 {
                return match.range
            }
        }
        
        return nil
    }
    
    // MARK: - 辅助方法
    
    /// 创建跳转链接
    private func createLink(
        for word: String,
        targetRange: CursorPosition,
        content: String
    ) -> JumpToDefinitionLink {
        let swiftRange = Range(targetRange.range, in: content) ?? content.startIndex..<content.endIndex
        let lineRange = content.lineRange(for: swiftRange)
        let nsLineRange = NSRange(lineRange, in: content)
        let linePreview = (content as NSString).substring(with: nsLineRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)
        
        return JumpToDefinitionLink(
            url: nil,  // nil 表示本地跳转
            targetRange: targetRange,
            typeName: word,
            sourcePreview: String(linePreview),
            documentation: nil,
            image: Image(systemName: "arrow.right.square.fill"),
            imageColor: Color(NSColor.systemBlue)
        )
    }

    private static func lspPosition(utf16Offset: Int, in text: String) -> Position? {
        guard utf16Offset >= 0, utf16Offset <= text.utf16.count else { return nil }
        var line = 0
        var character = 0
        var consumed = 0
        for unit in text.utf16 {
            if consumed >= utf16Offset {
                break
            }
            if unit == 0x0A {
                line += 1
                character = 0
            } else {
                character += 1
            }
            consumed += 1
        }
        return Position(line: line, character: character)
    }

    private static func nsRange(from lspRange: LSPRange, in content: String) -> NSRange? {
        guard let start = utf16Offset(for: lspRange.start, in: content),
              let end = utf16Offset(for: lspRange.end, in: content),
              end >= start else {
            return nil
        }
        return NSRange(location: start, length: end - start)
    }

    private static func utf16Offset(for position: Position, in content: String) -> Int? {
        var line = 0
        var utf16Offset = 0
        var lineStartOffset = 0
        for scalar in content.unicodeScalars {
            if line == position.line {
                break
            }
            utf16Offset += scalar.utf16.count
            if scalar == "\n" {
                line += 1
                lineStartOffset = utf16Offset
            }
        }
        guard line == position.line else { return nil }
        return min(lineStartOffset + position.character, content.utf16.count)
    }

    private static func previewLine(from fileURL: URL, at position: Position) -> String? {
        guard fileURL.isFileURL,
              let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        let lineIndex = Int(position.line)
        guard lines.indices.contains(lineIndex) else { return nil }
        return String(lines[lineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - NSRange 扩展

extension NSRange {
    /// 检查是否与另一个 NSRange 相交
    func intersects(_ other: NSRange) -> Bool {
        return NSIntersectionRange(self, other).length > 0
    }
}
