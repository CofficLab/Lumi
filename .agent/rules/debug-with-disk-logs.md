# 使用磁盘日志进行 Debug 的标准流程

> 当用户报告了一个 UI 异常或运行时行为问题（如「显示不支持的文件」），按照本流程通过写日志 → 运行 → 读磁盘日志的方式定位根因。

---

## 适用场景

- UI 显示异常，但无法直接从代码推断原因
- 状态机 / 异步流程出现竞态条件
- 某个视图分支走到了不该走的路径
- 启动、切换项目、打开文件等关键链路出错

---

## 总览

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ 1. 定位关键   │────▶│ 2. 在分支节点  │────▶│ 3. 构建 &    │────▶│ 4. 从磁盘读  │
│    决策路径   │     │    埋日志     │     │    运行 App  │     │    日志分析   │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

---

## 第一步：定位关键决策路径

阅读代码，找到**最终导致异常的那个分支**，然后沿调用链向上追踪。

### 示例

用户报告：「编辑器显示『不支持的文件』」

1. 在 `EditorPanelView.editorContent` 中找到 `unsupportedFileView` 分支
2. 向上追踪：谁决定了走这个分支？
   - `state.canPreview == false`
   - `state.isBinaryFile == false`
   - `projectVM.isFileSelected == true`
3. 继续向上：谁设置了 `canPreview`？
   - `EditorState.loadFile()` → 异步 Task 中设置 `canPreview = true`
4. 继续向上：谁调用了 `loadFile`？
   - `EditorPanelView.openOrActivateSession()`

**原则：追踪到数据源头（通常是 `@Published` 属性的赋值点）。**

---

## 第二步：在分支节点埋日志

在以下位置添加**无条件日志**（不受 `verbose` 开关控制）：

### 2.1 视图分支点（View 层）

在 SwiftUI `@ViewBuilder` 的每个分支添加诊断日志：

```swift
@ViewBuilder
private var editorContent: some View {
    if state.canPreview {
        sourceEditorContent
    } else if state.isBinaryFile, let fileURL = state.currentFileURL {
        FilePreviewView(fileURL: fileURL)
    } else if projectVM.isFileSelected {
        // 🔍 关键：记录走到此分支时的所有决策变量
        let _ = state.logger.warning(
            "📝[editorContent] unsupportedFileView shown. "
            + "canPreview=\(state.canPreview), "
            + "isBinaryFile=\(state.isBinaryFile), "
            + "currentFileURL=\(state.currentFileURL?.path ?? "nil"), "
            + "fileName=\(state.fileName), "
            + "fileExtension=\(state.fileExtension)"
        )
        unsupportedFileView
    }
}
```

**要点：**
- 用 `let _ =` 在 `@ViewBuilder` 中执行副作用
- 使用 `warning` 或 `error` 级别确保日志可见
- 输出**所有参与分支判断的变量**的值

### 2.2 状态变更点（ViewModel / State 层）

在状态赋值点前后加日志，捕获入参和中间值：

```swift
func loadFile(from url: URL?) {
    guard let url = url else {
        logger.info("📝[loadFile] url is nil → resetState")
        resetState()
        return
    }

    logger.info("📝[loadFile] start loading url=\(url.path)")

    Task {
        do {
            let loadedDocument = try documentController.loadDocument(from: url, ...)
            // 记录文档类型决策
            logger.info("📝[loadFile] document loaded: \(loadedDocument)")
            // ...
        } catch {
            // 记录异常
            logger.error("📝[loadFile] CATCH error=\(error.localizedDescription)")
        }
    }
}
```

### 2.3 异步边界

异步 `Task {}` 是最常见的竞态源头。在 Task 启动前和回调后都加日志：

```swift
// Task 启动前（同步上下文）
logger.info("📝[loadFile] start loading url=\(url.path)")

Task {
    // Task 回调后（异步上下文）
    logger.info("📝[loadFile] Task completed for url=\(url.path)")
    // ...
}
```

### 2.4 文档加载底层

在 `EditorDocumentController.loadDocument` 等底层方法中记录分类决策：

```swift
let isLikelyText = try isLikelyTextFile(url: url)
logger.info("📝[loadDocument] url=\(url.path), ext=\(ext), isLikelyText=\(isLikelyText)")

guard isLikelyText else {
    logger.info("📝[loadDocument] → .binary")
    return .binary(...)
}

logger.info("📝[loadDocument] → .text, contentLength=\(content.count)")
return .text(...)
```

---

## 第三步：构建 & 运行 App

```bash
# 构建
cd /Users/angel/Code/Coffic/Lumi
xcodebuild -project Lumi.xcodeproj -scheme Lumi -destination 'platform=macOS' build

# 运行（后台启动）
/Users/angel/Library/Developer/Xcode/DerivedData/Lumi-*/Build/Products/Debug/Lumi.app/Contents/MacOS/Lumi &
```

等待几秒让 App 完成启动和问题复现。

---

## 第四步：从磁盘读日志分析

### 4.1 找到最新日志文件

```bash
ls -lt ~/Library/Application\ Support/com.coffic.Lumi/Logs/ | head -5
```

### 4.2 过滤诊断日志

使用 `📝` 前缀快速过滤（所有诊断日志统一使用此前缀）：

```bash
grep "📝" ~/Library/Application\ Support/com.coffic.Lumi/Logs/<最新文件>.log
```

### 4.3 按时序分析

将日志按时间排序，重建事件流：

```
11:41:56.532  loadFile start loading url=...xcstrings          ← 异步 Task 启动
11:41:56.624  ❌ unsupportedFileView shown. canPreview=false    ← UI 渲染（Task 未完成）
11:41:57.231  document loaded: .text(...)                       ← Task 完成（晚 700ms）
11:41:57.263  shouldReplaceCurrentBuffer=false                  ← 并发重复调用被跳过
```

### 4.4 判断根因模式

| 日志模式 | 根因 | 修复方向 |
|----------|------|----------|
| `unsupportedFileView` 出现在 `loadFile` 完成**之前** | 异步竞态：UI 先渲染，数据后到达 | 添加 `isLoading` 状态或等待数据就绪 |
| `loadDocument → .binary` 但期望 `.text` | 文件类型误判 | 检查 `isLikelyTextFile` 逻辑 |
| `CATCH error=...` | 文件读取异常 | 检查文件权限、编码 |
| `shouldReplaceCurrentBuffer=false` | 重复调用被合并 | 检查调用时机 |
| `loadFile url is nil` | 上游未传递 URL | 检查 session/selection 流程 |

---

## 日志规范

### 命名约定

- 前缀：`📝[方法名]`，如 `📝[loadFile]`、`📝[editorContent]`、`📝[loadDocument]`
- 箭头：用 `→` 表示决策结果，如 `→ .binary`、`→ resetState`
- 变量：`key=value` 格式，用逗号分隔

### 级别选择

| 场景 | 级别 |
|------|------|
| 正常流程跟踪 | `info` |
| 走到异常分支 | `warning` |
| 捕获错误 | `error` |

### 隐私

对用户路径等 PII 数据使用 `privacy: .public`（调试阶段可接受）：

```swift
logger.info("📝[loadFile] url=\(url.path, privacy: .public)")
```

---

## 日志清理

**定位并修复问题后，移除调试日志（保留有长期价值的关键路径日志除外）。**

调试日志的标志：
- `📝` 前缀
- `warning` 级别但非真正警告
- 记录临时变量组合

可保留的日志：
- `loadFile` 入口的 `info` 级别日志（有长期诊断价值）
- `catch` 块中的 `error` 级别日志（始终有价值）

---

## 相关规范

- [Swift 日志记录规范](./swift-log.md) — Logger 分配、级别、格式
- [第一性原理思考规范](./first-principles-thinking.md) — 问题分析方法论
