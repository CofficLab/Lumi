# 改进建议：代码补全与建议系统

**参考产品**: Cursor Tab, GitHub Copilot, Codeium  
**优先级**: 🟠 高  
**影响范围**: UI, AgentTool, ContextService

---

## 背景

Cursor Tab 和 GitHub Copilot 提供了流畅的代码补全体验：

- 实时代码补全，随打随补
- 多行补全建议
- 上下文感知补全
- 补全预览和接受机制
- 补全学习和优化

当前 Lumi 作为 macOS 应用，可以考虑添加类似的代码补全能力。

---

## 改进方案

### 1. 补全服务架构

```swift
/// 代码补全服务
class CodeCompletionService: ObservableObject {
    /// 补全提供者
    private let providers: [CompletionProvider]
    
    /// 补全缓存
    private var cache: [String: CachedCompletion] = [:]
    
    /// 获取补全建议
    func getCompletions(
        for document: DocumentContext,
        position: CursorPosition,
        trigger: CompletionTrigger
    ) async -> [CompletionItem] {
        // 检查缓存
        let cacheKey = generateCacheKey(document: document, position: position)
        if let cached = cache[cacheKey], !cached.isExpired {
            return cached.items
        }
        
        // 收集所有提供者的建议
        var allCompletions: [CompletionItem] = []
        
        for provider in providers {
            let completions = await provider.provideCompletions(
                document: document,
                position: position,
                trigger: trigger
            )
            allCompletions.append(contentsOf: completions)
        }
        
        // 排序和过滤
        let sorted = rankCompletions(allCompletions, context: document)
        let filtered = deduplicateCompletions(sorted)
        
        // 缓存结果
        cache[cacheKey] = CachedCompletion(items: filtered)
        
        return filtered
    }
    
    /// 接受补全
    func acceptCompletion(_ item: CompletionItem) async {
        // 记录接受，用于学习
        await CompletionTelemetry.shared.recordAcceptance(item)
    }
    
    /// 拒绝补全
    func rejectCompletion(_ item: CompletionItem) async {
        await CompletionTelemetry.shared.recordRejection(item)
    }
}

/// 补全提供者协议
protocol CompletionProvider {
    var priority: Int { get }
    
    func provideCompletions(
        document: DocumentContext,
        position: CursorPosition,
        trigger: CompletionTrigger
    ) async -> [CompletionItem]
}

/// 补全项
struct CompletionItem: Identifiable {
    let id: UUID
    let text: String
    let displayText: String
    let kind: CompletionKind
    let source: CompletionSource
    let score: Double
    let range: TextRange
    let detail: String?
    let documentation: String?
    
    enum CompletionKind {
        case text
        case method
        case function
        case constructor
        case field
        case variable
        case `class`
        case `struct`
        case `enum`
        case `protocol`
        case keyword
        case snippet
    }
    
    enum CompletionSource {
        case languageServer
        case ai
        case snippet
        case history
    }
}

/// 补全触发类型
enum CompletionTrigger {
    case character(Char)  // 特定字符触发
    case manual           // 手动触发
    case auto             // 自动触发
}

/// 文档上下文
struct DocumentContext {
    let uri: URL
    let language: String
    let content: String
    let lineCount: Int
    let cursorLine: Int
    let cursorColumn: Int
    let surroundingCode: SurroundingCode
    
    struct SurroundingCode {
        let before: String    // 光标前 50 行
        let after: String     // 光标后 50 行
        let currentLine: String
        let indent: String    // 当前行缩进
    }
}
```

---

### 2. AI 补全提供者

```swift
/// AI 补全提供者
class AICompletionProvider: CompletionProvider {
    let priority: Int = 100  // 最高优先级
    
    private let llmService: LLMService
    private let config: AICompletionConfig
    
    /// 提供补全
    func provideCompletions(
        document: DocumentContext,
        position: CursorPosition,
        trigger: CompletionTrigger
    ) async -> [CompletionItem] {
        // 构建补全请求
        let prompt = buildCompletionPrompt(
            document: document,
            position: position
        )
        
        // 调用 LLM
        do {
            let response = try await llmService.sendMessage(
                messages: [ChatMessage(role: .user, content: prompt)],
                config: config.llmConfig
            )
            
            // 解析补全结果
            return parseCompletions(
                from: response.content,
                document: document,
                position: position
            )
        } catch {
            return []
        }
    }
    
    /// 构建补全提示词
    private func buildCompletionPrompt(
        document: DocumentContext,
        position: CursorPosition
    ) -> String {
        let before = document.surroundingCode.before
        let currentLine = document.surroundingCode.currentLine
        let after = document.surroundingCode.after
        
        return """
        You are an intelligent code completion assistant. Complete the code based on the context.
        
        Language: \(document.language)
        
        Code before cursor:
        ```
        \(before.suffix(2000))
        ```
        
        Current line:
        ```
        \(currentLine)
        ```
        
        Code after cursor:
        ```
        \(after.prefix(500))
        ```
        
        Rules:
        1. Provide the most likely completion
        2. Continue the current line or suggest a new block
        3. Match the code style and indentation
        4. Return only the completion text, no explanations
        
        Completion:
        """
    }
    
    /// 解析补全结果
    private func parseCompletions(
        from response: String,
        document: DocumentContext,
        position: CursorPosition
    ) -> [CompletionItem] {
        // 清理响应
        var completion = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除可能的 markdown 标记
        if completion.hasPrefix("```") {
            completion = completion
                .replacingOccurrences(of: "^```\\w*\n", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\n```$", with: "", options: .regularExpression)
        }
        
        // 创建补全项
        return [
            CompletionItem(
                id: UUID(),
                text: completion,
                displayText: truncateForDisplay(completion),
                kind: inferKind(from: completion),
                source: .ai,
                score: 0.9,
                range: TextRange(
                    start: position,
                    end: position
                ),
                detail: nil,
                documentation: nil
            )
        ]
    }
    
    /// 推断补全类型
    private func inferKind(from text: String) -> CompletionItem.CompletionKind {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        
        if trimmed.hasPrefix("func ") { return .function }
        if trimmed.hasPrefix("var ") || trimmed.hasPrefix("let ") { return .variable }
        if trimmed.hasPrefix("class ") { return .class }
        if trimmed.hasPrefix("struct ") { return .struct }
        if trimmed.hasPrefix("enum ") { return .enum }
        if trimmed.hasPrefix("protocol ") { return .protocol }
        
        return .text
    }
}
```

---

### 3. 多行补全支持

```swift
/// 多行补全管理器
class MultiLineCompletionManager {
    /// 生成多行补全
    func generateMultiLineCompletion(
        document: DocumentContext,
        position: CursorPosition,
        maxLines: Int = 20
    ) async -> MultiLineCompletion? {
        // 分析当前上下文
        let context = analyzeContext(document: document, position: position)
        
        // 根据上下文决定补全策略
        switch context.kind {
        case .functionBody:
            return await generateFunctionBody(document: document, position: position)
        case .classBody:
            return await generateClassBody(document: document, position: position)
        case .conditionalBlock:
            return await generateConditionalBlock(document: document, position: position)
        case .loopBlock:
            return await generateLoopBlock(document: document, position: position)
        default:
            return await generateGenericCompletion(document: document, position: position)
        }
    }
    
    /// 分析上下文
    private func analyzeContext(
        document: DocumentContext,
        position: CursorPosition
    ) -> CodeContext {
        let currentLine = document.surroundingCode.currentLine
        let beforeLines = document.surroundingCode.before.split(separator: "\n")
        
        // 检查是否在函数体内
        if let lastFunc = beforeLines.last(where: { $0.contains("func ") }) {
            let indentation = currentLine.prefix(while: { $0 == " " || $0 == "\t" })
            return CodeContext(
                kind: .functionBody,
                indentation: String(indentation),
                context: String(lastFunc)
            )
        }
        
        // 检查是否在条件块内
        if let lastIf = beforeLines.last(where: { $0.contains("if ") }) {
            return CodeContext(
                kind: .conditionalBlock,
                indentation: detectIndentation(currentLine),
                context: String(lastIf)
            )
        }
        
        return CodeContext(kind: .unknown, indentation: "", context: "")
    }
    
    /// 生成函数体
    private func generateFunctionBody(
        document: DocumentContext,
        position: CursorPosition
    ) async -> MultiLineCompletion? {
        // 使用 AI 生成函数实现
        // ...
    }
}

/// 多行补全结果
struct MultiLineCompletion {
    let lines: [String]
    let totalText: String
    let preview: String  // 用于预览的简短版本
    let confidence: Double
    
    var lineCount: Int { lines.count }
}

/// 代码上下文
struct CodeContext {
    let kind: ContextKind
    let indentation: String
    let context: String
    
    enum ContextKind {
        case functionBody
        case classBody
        case conditionalBlock
        case loopBlock
        case unknown
    }
}
```

---

### 4. 补全预览与接受

```swift
/// 补全预览视图
struct CompletionPreviewView: View {
    let completion: CompletionItem
    let document: DocumentContext
    @Binding var isAccepted: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 补全文本预览
            ScrollView(.horizontal, showsIndicators: false) {
                Text(highlightedText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
            }
            
            // 操作按钮
            HStack(spacing: 8) {
                Button("接受 (Tab)") {
                    isAccepted = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("拒绝 (Esc)") {
                    isAccepted = false
                }
                
                Spacer()
                
                Text(completion.source.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(radius: isHovering ? 4 : 2)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private var highlightedText: AttributedString {
        // 高亮显示补全差异
        var result = AttributedString(completion.text)
        
        // 高亮新增部分
        if let range = result.range(of: completion.text) {
            result[range].backgroundColor = Color.green.opacity(0.2)
        }
        
        return result
    }
}

/// 内联补全渲染器（用于编辑器）
class InlineCompletionRenderer {
    weak var textView: NSTextView?
    
    /// 显示幽灵文本
    func showGhostText(_ text: String, at position: Int) {
        guard let textView = textView else { return }
        
        // 创建灰色文本
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.placeholderTextColor,
            .font: textView.font ?? NSFont.systemFont(ofSize: 13)
        ]
        
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        
        // 显示为幽灵文本
        // 实现细节取决于使用的编辑器组件
    }
    
    /// 隐藏幽灵文本
    func hideGhostText() {
        // 移除幽灵文本
    }
    
    /// 接受补全
    func acceptCompletion(_ text: String, at position: Int) {
        guard let textView = textView else { return }
        
        // 插入文本
        let range = NSRange(location: position, length: 0)
        textView.textStorage?.replaceCharacters(in: range, with: text)
    }
}
```

---

### 5. 补全学习与优化

```swift
/// 补全遥测
class CompletionTelemetry {
    static let shared = CompletionTelemetry()
    
    private var stats: CompletionStats = CompletionStats()
    
    /// 记录接受
    func recordAcceptance(_ item: CompletionItem) async {
        stats.acceptances += 1
        
        // 记录详细统计
        stats.bySource[item.source, default: 0] += 1
        stats.byKind[item.kind, default: 0] += 1
        
        // 更新模型
        await updateModel(for: item)
    }
    
    /// 记录拒绝
    func recordRejection(_ item: CompletionItem) async {
        stats.rejections += 1
        
        // 记录拒绝原因分析
        await analyzeRejection(item)
    }
    
    /// 更新学习模型
    private func updateModel(for item: CompletionItem) async {
        // 根据用户接受的模式优化排序
        // 例如：如果用户经常接受某种类型的补全，提高其优先级
    }
    
    /// 分析拒绝原因
    private func analyzeRejection(_ item: CompletionItem) async {
        // 分析为什么用户拒绝了这个补全
        // 可以用于改进模型
    }
    
    /// 获取统计数据
    func getStats() -> CompletionStats {
        stats
    }
}

/// 补全统计
struct CompletionStats {
    var acceptances: Int = 0
    var rejections: Int = 0
    var bySource: [CompletionItem.CompletionSource: Int] = [:]
    var byKind: [CompletionItem.CompletionKind: Int] = [:]
    
    var acceptanceRate: Double {
        let total = acceptances + rejections
        guard total > 0 else { return 0 }
        return Double(acceptances) / Double(total)
    }
}
```

---

### 6. 快捷键和手势支持

```swift
/// 补全快捷键管理
class CompletionKeyBindings {
    var bindings: [KeyBinding] = [
        .init(key: .tab, action: .acceptCompletion),
        .init(key: .escape, action: .rejectCompletion),
        .init(key: .enter, modifiers: .option, action: .acceptAndNewline),
        .init(key: .rightArrow, modifiers: .command, action: .acceptWord),
        .init(key: .down, modifiers: .control, action: .nextCompletion),
        .init(key: .up, modifiers: .control, action: .previousCompletion),
    ]
    
    /// 处理键盘事件
    func handle(_ event: NSEvent) -> CompletionAction? {
        for binding in bindings {
            if binding.matches(event) {
                return binding.action
            }
        }
        return nil
    }
}

struct KeyBinding {
    let key: Key
    let modifiers: NSEvent.ModifierFlags
    let action: CompletionAction
    
    init(key: Key, modifiers: NSEvent.ModifierFlags = [], action: CompletionAction) {
        self.key = key
        self.modifiers = modifiers
        self.action = action
    }
    
    func matches(_ event: NSEvent) -> Bool {
        guard key.matches(event) else { return false }
        return event.modifierFlags == modifiers
    }
}

enum Key {
    case tab
    case escape
    case enter
    case rightArrow
    case down
    case up
    
    func matches(_ event: NSEvent) -> Bool {
        switch self {
        case .tab: return event.keyCode == 48
        case .escape: return event.keyCode == 53
        case .enter: return event.keyCode == 36
        case .rightArrow: return event.keyCode == 124
        case .down: return event.keyCode == 125
        case .up: return event.keyCode == 126
        }
    }
}

enum CompletionAction {
    case acceptCompletion
    case rejectCompletion
    case acceptAndNewline
    case acceptWord
    case nextCompletion
    case previousCompletion
    case showMore
}
```

---

## 实施计划

### 阶段 1: 基础架构 (2 周)
1. 实现 `CodeCompletionService`
2. 创建补全数据模型
3. 实现基础 UI 组件

### 阶段 2: AI 集成 (2 周)
1. 实现 `AICompletionProvider`
2. 集成 LLM 服务
3. 优化补全提示词

### 阶段 3: 高级功能 (2 周)
1. 多行补全支持
2. 学习和优化
3. 快捷键和手势

---

## 预期效果

1. **编码效率**: 补全接受率 30%+ 可节省大量输入
2. **上下文感知**: AI 理解代码上下文，提供相关补全
3. **学习优化**: 根据用户习惯持续改进
4. **流畅体验**: 内联显示，无缝集成

---

## 参考资源

- [Cursor Tab](https://cursor.sh/docs/tab)
- [GitHub Copilot](https://github.com/features/copilot)
- [Codeium](https://codeium.com/)
- [LSP Specification](https://microsoft.github.io/language-server-protocol/)

---

*创建时间: 2026-03-13*