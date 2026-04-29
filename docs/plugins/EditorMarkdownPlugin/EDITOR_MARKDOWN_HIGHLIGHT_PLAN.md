# Markdown Syntax Highlight Plugin Plan

## 背景

当前 `AgentEditorPlugin` 对 Markdown 文件 (`*.md`, `*.mdx`) 缺乏源码级别的语法高亮。

由于底层引擎 `CodeEditSourceEditor` 依赖 `tree-sitter` 进行语法分析，而 `tree-sitter` 对 Markdown 的支持有限，导致 Markdown 文件在源码模式下退化为 `plainText`，没有任何高亮效果。

本方案旨在通过**插件机制**为 Markdown 提供源码级高亮，同时确保架构的可扩展性。

---

## 核心方案：内核注入点 + 插件实现

### 1. 编辑器内核增加注入点

在现有的 `EditorFeaturePlugin` 体系中，扩展一个新的贡献者类型：

```swift
// EditorExtensionContributors.swift
@MainActor
protocol EditorHighlightProviderContributor: AnyObject {
    var id: String { get }
    func supports(languageId: String) -> Bool
    func createHighlightProvider() -> any HighlightProviding
}
```

### 2. 插件实现 Markdown 高亮

创建 `MarkdownEditorPlugin`，实现 `EditorHighlightProviderContributor`：

```swift
final class MarkdownSyntaxHighlighter: HighlightProviding {
    func queryHighlightsFor(
        textView: TextView, 
        range: NSRange, 
        completion: @escaping @MainActor (Result<[HighlightRange], Error>) -> Void
    ) {
        // 使用正则匹配 Markdown 语法元素
        let highlights = analyzeMarkdownRanges(text, in: range)
        completion(.success(highlights))
    }
}
```

---

## 与 VS Code 架构的对齐

| 维度 | VS Code 的做法 | Lumi 的设计方案 | 评价 |
| :--- | :--- | :--- | :--- |
| **注入方式** | JSON 配置声明 (`contributes.grammars`) | Swift 协议注册 (`register(into:)`) | 异曲同工，Swift 更灵活 |
| **高亮规则** | TextMate Grammar (正则) | `HighlightProviding` 协议 (正则) | 一致 |
| **渲染引擎** | Monaco Editor | CodeEditTextView | 一致，引擎只负责"按指令上色" |
| **扩展能力** | 任何插件都能加新语言高亮 | 任何插件都能加新语言高亮 | 一致 |

这正是 VS Code "Platform + Plugin" 的核心设计理念。

---

## Markdown 语法元素映射

| Markdown 元素 | 正则模式示例 | 建议着色 |
|--------------|-------------|---------|
| `# 标题 1-6` | `^#{1,6}\s+` | 标题色（粗体、蓝色/紫色） |
| `**粗体**` | `\*\*(.+?)\*\*` | 粗体标记色 |
| `*斜体*` | `\*(.+?)\*` | 斜体标记色 |
| `` `行内代码` `` | `` `[^`]+` `` | 代码色（等宽、橙色） |
| `![图片](url)` | `!\[.*?\]\(.*?\)` | 图片链接色 |
| `[链接](url)` | `\[.*?\]\(.*?\)` | 链接色（蓝色） |
| `> 引用` | `^\s*>\s*` | 引用色（灰色） |
| `- 列表项` | `^\s*[-*+]\s` | 列表标记色 |
| `1. 有序列表` | `^\s*\d+\.\s` | 列表数字色 |
| `[ ] 任务列表` | `^\s*[-*+]\s\[[ x]\]` | 复选框色 |
| `---` 分隔线 | `^\s*[-*_]{3,}\s*$` | 分隔线色 |
| ``` ``` 代码块 ``` | `` ```(\w*)\n[\s\S]*?``` `` | 代码块边界色 |

---

## 具体实现步骤

### Step 1: 定义协议 (EditorExtensionContributors.swift)

新增 `EditorHighlightProviderContributor`，并添加注册/查询方法到 `EditorExtensionRegistry`。

### Step 2: SourceEditorView 收集高亮提供者

修改 `activeHighlightProviders` 属性，从插件系统获取语言专用的高亮提供者：

```swift
private var activeHighlightProviders: [any HighlightProviding] {
    var providers: [any HighlightProviding] = [treeSitterClient]
    // 插入插件提供的高亮提供者
    let langId = resolvedLanguage.tsName ?? "plaintext"
    if let pluginProvider = state.editorExtensions.highlightProvider(for: langId) {
        providers.insert(pluginProvider, at: 1)
    }
    return providers
}
```

### Step 3: 创建 MarkdownEditorPlugin

在 `Plugins-Editor/` 下新建 `MarkdownEditorPlugin/` 目录，包含：
- `MarkdownEditorPlugin.swift`: 插件入口，注册贡献者。
- `MarkdownSyntaxHighlighter.swift`: 高亮核心逻辑。

### Step 4: 性能验证

确保在大文件和快速滚动场景下，高亮逻辑符合 Phase 8 的指标。

---

## 与现有 Roadmap 的兼容性

### ✅ 架构方向：符合

- 延续了 `EditorFeaturePlugin` 的插件化方向（Roadmap: "有 editor feature plugin / contributor 结构"）。
- 属于 Layer 4: Language Core 的能力扩展。
- `SourceEditorView` 只负责桥接，不持有高亮逻辑（Execution Plan: "视图层只负责展示和桥接"）。

### ⚠️ 优先级说明

本方案属于**内核稳定后的扩展能力**，不属于 Roadmap 中 Phase 1-9 的核心路径（Buffer、Transaction、Session、Workbench）。应在内核基础设施稳固后实施。

### ⚠️ 性能约束（严格遵守 Phase 8 标准）

必须遵守 Roadmap Phase 8 中定义的性能约束：

1. **Viewport 限流**：高亮扫描仅限于可见区域 + 少量缓冲行。
2. **大文件模式**：当 `LargeFileMode` 为 `.large` 或 `.mega` 时，Markdown 高亮应自动降级或禁用。
3. **增量更新**：监听 `applyEdit` 回调，仅刷新受影响的范围，避免全量重新扫描。
4. **主线程压力**：正则匹配应在后台线程执行，结果在主线程应用。

---

## 方案评估

| 维度 | 评价 |
|------|------|
| **可行性** | ✅ 架构支持，只需新增一个贡献者类型 |
| **侵入性** | 中 — 需修改 `EditorExtensionContributors`、`EditorExtensionRegistry`、`SourceEditorView` 三处 |
| **性能** | 正则匹配对大文件可能较慢，必须限制扫描范围和增量更新 |
| **可维护性** | 高 — 独立的插件，不影响其他语言的高亮 |

### 与其他方案对比

| 方案 | 改动量 | 高亮质量 | 备注 |
|------|--------|---------|------|
| **A. 新增 HighlightProvider 贡献者** | 中 | 好（正则匹配） | 最灵活，可按语言定制 |
| **B. 添加 tree-sitter-markdown** | 小 | 好（语法树） | 需确认 CodeEditLanguages 是否支持 |
| **C. 修改 resolvedLanguage 强制映射** | 最小 | 差（tree-sitter 不支持 Markdown） | 不可行 |

**推荐方案 A**。

---

## 执行进度

- [ ] 内核层：新增 `EditorHighlightProviderContributor` 协议及注册机制
- [ ] 桥接层：`SourceEditorView` 注入插件高亮提供者
- [ ] 插件层：创建 `MarkdownEditorPlugin`
- [ ] 性能验证：Viewport 限流、大文件降级、增量更新
