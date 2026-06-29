import Foundation
import AppKit
import SwiftUI
import Combine
import EditorSource
import EditorTextView
import EditorLanguageRuntime
import SwiftTreeSitter
import LanguageServerProtocol
import MagicAlert
import os
import SuperLogKit

/// Jump-to-definition delegate
/// 基于 Tree-Sitter AST 实现文件内跳转（Cmd+Click）
/// 
/// 工作原理：
/// 1. 用户按住 Cmd 并点击标识符
/// 2. EditorSource 的 JumpToDefinitionModel 检测到交互
/// 3. 调用此 Delegate 的 queryLinks 方法
/// 4. 此方法通过 AST 或正则查找定义位置
/// 5. 引擎自动执行跳转或显示多定义弹窗
@preconcurrency
public final class EditorJumpToDefinitionDelegate: ObservableObject, JumpToDefinitionDelegate, SuperLog {
    public nonisolated static let emoji = "🔗"
    nonisolated static let verbose = true
    private let logger = Logger(subsystem: EditorHostEnvironment.current.logSubsystem, category: "editor.jump-to-definition")
    
    public weak var treeSitterClient: TreeSitterClient?
    public weak var textStorage: NSTextStorage?
    public weak var lspClient: (any SuperEditorLSPClient)?
    public var lspClientProvider: (() -> (any SuperEditorLSPClient)?)?
    weak var textViewController: TextViewController?
    public var semanticCapabilityProvider: (() -> (any SuperEditorSemanticCapability)?)?
    public var currentFileURLProvider: (() -> URL?)?
    public var onOpenExternalDefinition: ((URL, CursorPosition) -> Void)?
    public var allowsLocalFallbackProvider: (() -> Bool)?
    private let requestGeneration = RequestGeneration()

    public init() {}

    private var activeTreeSitterClient: TreeSitterClient? {
        textViewController?.treeSitterClient ?? treeSitterClient
    }
    
    // MARK: - JumpToDefinitionDelegate
    
    /// 查询定义链接 - 当用户 Cmd+Click 时，引擎调用此方法查找目标
    @MainActor
    public func queryLinks(forRange range: NSRange, textView: TextViewController) async -> [JumpToDefinitionLink]? {
        guard let textStorage = textStorage else { return nil }
        let generation = requestGeneration.next()
        
        let content = textStorage.string
        guard let word = Self.substringIfValid(in: content, range: range) else {
            return nil
        }
        
        // 过滤无效输入
        guard !word.isEmpty, word.rangeOfCharacter(from: .alphanumerics) != nil else {
            return nil
        }
        
        if Self.verbose {
            logger.debug("\(self.t)跳转到定义: '\(word)' 位置=\(range.location)")
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
            if Self.verbose {
                logger.debug("\(self.t)LSP 匹配: '\(word)'")
            }
            return [link]
        }

        // LSP 未命中时仍尝试同文件 AST（索引或 build context 未就绪时常见）。
        if let definitionRange = await findDefinitionViaAST(
            word: word,
            cursorRange: range,
            content: content
        ) {
            guard requestGeneration.isCurrent(generation) else { return nil }
            let position = CursorPosition(range: definitionRange)
            if Self.verbose {
                logger.debug("\(self.t)AST 匹配: '\(word)' -> \(definitionRange.location)")
            }
            return [createLink(for: word, targetRange: position, content: content)]
        }
        
        // 回退：通过正则匹配（LSP/AST 均未命中时）
        if let fallbackRange = findDefinitionViaRegex(
            word: word,
            cursorRange: range,
            content: content
        ) {
            guard requestGeneration.isCurrent(generation) else { return nil }
            let position = CursorPosition(range: fallbackRange)
            if Self.verbose {
                logger.debug("\(self.t)正则匹配: '\(word)' -> \(fallbackRange.location)")
            }
            return [createLink(for: word, targetRange: position, content: content)]
        }
        
        if Self.verbose {
            logger.debug("\(self.t)未找到定义: '\(word)'")
        }
        return nil
    }
    
    /// 打开链接（本地跳转由引擎自动处理，这里仅记录日志）
    public func openLink(link: JumpToDefinitionLink) {
        if Self.verbose {
            logger.debug("\(self.t)打开链接: \(link.label) -> \(link.url?.absoluteString ?? "本地")")
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
        guard let word = Self.substringIfValid(in: content, range: range) else {
            return
        }
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

        // 2. 回退：通过 AST（仅 Definition 支持；LSP 未就绪时仍可同文件跳转）
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

    @MainActor
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
    @MainActor
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
    @MainActor
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
    @MainActor
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
            case .definition: return String(localized: "Finding definition...", bundle: .module)
            case .declaration: return String(localized: "Finding declaration...", bundle: .module)
            case .typeDefinition: return String(localized: "Finding type definition...", bundle: .module)
            case .implementation: return String(localized: "Finding implementation...", bundle: .module)
            }
        }

        var toastNotFound: String {
            switch self {
            case .definition: return String(localized: "No definition found", bundle: .module)
            case .declaration: return String(localized: "No declaration found", bundle: .module)
            case .typeDefinition: return String(localized: "No type definition found", bundle: .module)
            case .implementation: return String(localized: "No implementation found", bundle: .module)
            }
        }
    }

    @MainActor
    private func navigationFailureMessage(kind: LSPNavigationKind, symbolName: String) -> String {
        semanticCapabilityProvider?()?.missingResultMessage(
            uri: currentFileURLProvider?()?.absoluteString,
            operation: operationName(for: kind),
            symbolName: symbolName
        ) ?? kind.toastNotFound
    }

    @MainActor
    private func navigationPreflightFailureMessage(kind: LSPNavigationKind, symbolName: String) -> String? {
        semanticCapabilityProvider?()?.preflightMessage(
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
        guard let lspClient = lspClientProvider?() ?? lspClient else {
            logger.warning("\(self.t)LSP 跳转取消: lspClient 不存在, kind=\(String(describing: kind), privacy: .public), word=\(word, privacy: .public)")
            return nil
        }

        guard let lspPosition = Self.lspPosition(utf16Offset: cursorRange.location, in: content) else {
            logger.warning("\(self.t)LSP 跳转取消: 无法换算 LSP 位置, kind=\(String(describing: kind), privacy: .public), word=\(word, privacy: .public), range=\(cursorRange.location)-\(cursorRange.length)")
            return nil
        }
        let currentFileURL = currentFileURLProvider?()
        let currentURI = currentFileURL?.absoluteString
        logger.info(
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
            logger.warning(
                "\(self.t)LSP 跳转无结果: kind=\(String(describing: kind), privacy: .public), word=\(word, privacy: .public), currentURI=\(currentURI ?? "<nil>", privacy: .public), lspLine=\(lspPosition.line), lspCharacter=\(lspPosition.character)"
            )
            return nil
        }
        logger.info(
            "\(self.t)LSP 跳转命中: kind=\(String(describing: kind), privacy: .public), word=\(word, privacy: .public), targetURI=\(location.uri, privacy: .public), start=\(location.range.start.line):\(location.range.start.character), end=\(location.range.end.line):\(location.range.end.character)"
        )

        let targetURL = Self.fileURL(fromLSPURI: location.uri)
        let isSameFile = Self.isSameFile(currentFileURL: currentFileURL, targetURL: targetURL)

        if isSameFile,
           let targetRange = Self.nsRange(from: location.range, in: content) {
            return createLink(
                for: word,
                targetRange: CursorPosition(range: NSRange(location: targetRange.location, length: 0)),
                content: content
            )
        }

        guard let url = targetURL else { return nil }
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

    @MainActor
    private func allowsLocalFallbackForDefinition() -> Bool {
        allowsLocalFallbackProvider?() ?? true
    }
    
    // MARK: - AST 查找（核心逻辑）
    
    /// 通过 Tree-Sitter AST 查找定义
    @MainActor
    private func findDefinitionViaAST(
        word: String,
        cursorRange: NSRange,
        content: String
    ) async -> NSRange? {
        guard let treeSitterClient = activeTreeSitterClient else { return nil }

        do {
            // 从语法树根节点搜索整文件；从光标子树无法找到其它位置的同名定义。
            let roots = try treeSitterClient.rootNodes()
            for root in roots {
                if let defRange = searchNodeTree(
                    word: word,
                    cursorRange: cursorRange,
                    node: root.node,
                    content: content
                ) {
                    return defRange
                }
            }
        } catch {
            if Self.verbose {
                logger.debug("\(self.t)AST 查询失败: \(error.localizedDescription, privacy: .public)")
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
        let cursor = node.treeCursor
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
            "variable_declarator",
            "protocol_declaration", "initializer_declaration", "init_declaration",
            "typealias_declaration", "subscript_declaration", "actor_declaration",
            "associatedtype_declaration", "deinit_declaration",
        ]
        
        // 检查是否是定义节点
        let isDefinition = definitionKeywords.contains { nodeType.contains($0) }
        guard isDefinition else { return nil }
        
        // 查找定义名称
        guard let nameRange = extractDefinitionName(node: node) else { return nil }
        guard let name = Self.substringIfValid(in: content, range: nameRange) else { return nil }
        
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
        let cursor = node.treeCursor
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

    /// 正则表达式缓存，按 escapedWord 缓存编译后的正则数组
    nonisolated(unsafe) private static var regexCache: [String: [NSRegularExpression]] = [:]
    private static let regexCacheLock = NSLock()
    private static let maxCacheSize = 50

    /// 通过正则回退查找定义（支持多语言）
    private func findDefinitionViaRegex(
        word: String,
        cursorRange: NSRange,
        content: String
    ) -> NSRange? {
        let escapedWord = NSRegularExpression.escapedPattern(for: word)

        // 获取或编译正则表达式
        let regexes: [NSRegularExpression]
        if let cached = Self.regexCache[escapedWord] {
            regexes = cached
        } else {
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

            regexes = patterns.compactMap { try? NSRegularExpression(pattern: $0, options: []) }

            // 缓存编译结果
            Self.regexCacheLock.lock()
            if Self.regexCache.count >= Self.maxCacheSize {
                // 简单清理：移除一半缓存
                let keysToRemove = Array(Self.regexCache.keys.prefix(Self.maxCacheSize / 2))
                for key in keysToRemove {
                    Self.regexCache.removeValue(forKey: key)
                }
            }
            Self.regexCache[escapedWord] = regexes
            Self.regexCacheLock.unlock()
        }

        let nsContent = content as NSString
        let searchRange = NSRange(location: 0, length: max(0, min(cursorRange.location, nsContent.length)))

        for regex in regexes {
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

    static func substringIfValid(in text: String, range: NSRange) -> String? {
        let nsText = text as NSString
        guard range.location >= 0,
              range.length >= 0,
              range.location <= nsText.length,
              range.length <= nsText.length - range.location else {
            return nil
        }
        return nsText.substring(with: range)
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
              let content = try? EditorTextFileReader.read(fileURL) else { return nil }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        let lineIndex = Int(position.line)
        guard lines.indices.contains(lineIndex) else { return nil }
        return String(lines[lineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func fileURL(fromLSPURI uri: String) -> URL? {
        WorkspaceEditFileOperations.fileURL(from: uri)
    }

    static func isSameFile(currentFileURL: URL?, targetURL: URL?) -> Bool {
        guard let currentFileURL, let targetURL else { return false }
        return currentFileURL.standardizedFileURL == targetURL.standardizedFileURL
    }
}

// MARK: - Testing

extension EditorJumpToDefinitionDelegate {
    /// 从已解析语法树根节点查找定义，供单元测试验证 AST 搜索策略。
    func findDefinitionInTreeRoot(
        word: String,
        cursorRange: NSRange,
        content: String,
        root: Node
    ) -> NSRange? {
        searchNodeTree(
            word: word,
            cursorRange: cursorRange,
            node: root,
            content: content
        )
    }

    /// 从光标附近子树查找定义，用于回归测试「只搜子树会漏掉远处定义」。
    func findDefinitionInCursorSubtree(
        word: String,
        cursorRange: NSRange,
        content: String,
        cursorNode: Node
    ) -> NSRange? {
        searchNodeTree(
            word: word,
            cursorRange: cursorRange,
            node: cursorNode,
            content: content
        )
    }
}

// MARK: - NSRange 扩展

extension NSRange {
    /// 检查是否与另一个 NSRange 相交
    func intersects(_ other: NSRange) -> Bool {
        return NSIntersectionRange(self, other).length > 0
    }
}
