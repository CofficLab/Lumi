# 预览右键选中区块 → 发给 LLM 讨论/修改

## 结论先行
**可以实现，且无需新增任何 kernel 协议。** 你担心的"预填输入框文本能力"其实已经存在：`kernel.conversationInput?.text`（`ConversationInputProviding` 协议，`StoryWriterPlugin` 已在用）。所以方案就是：在 `HTMLPreviewView` 里注入 JS 拦截右键 → 高亮最近的 `data-block` 区块 + 浮动"发给助手"按钮 → 经 `WKScriptMessageHandler` 把区块 `outerHTML` 回传 Swift → 组装成草稿写入 `kernel.conversationInput.text`。LLM 那侧改 HTML 用现成的 `_patch_html` / `_replace_html` 工具，落盘后 `WorkspaceStore.reload()` 自动刷新预览，闭环完成。

## 改动文件（共 5 处）

### 1. `Packages/AppStorePromoKit/.../AppStorePromoTemplateFactory.swift` — 给区块打标
在默认模板的两个 `<section>` 上加 `data-block` 属性，让 JS 能精确选中：
- `<section class="copy">` → `<section class="copy" data-block="headline" data-block-label="标题文案">`
- `<section class="device">` → `<section class="device" data-block="screenshot" data-block-label="截图框">`

`data-block` 是机器标识（回传用），`data-block-label` 是给人看的中文标签（草稿里引用）。这两行改动只影响新建任务的默认模板，不破坏存量 HTML（存量 HTML 没有 `data-block`，JS 兜底逻辑见下）。

### 2. `Packages/HTMLPreviewKit/.../HTMLPreviewView.swift` — 注入选区交互（核心）
这是改动最多的文件。在现有 `_WKWebViewWrapper` 上扩展：

- **`init` 新增可选闭包参数**：`onBlockSelected: ((PromoBlockSelection) -> Void)?` 和 `onBlockCleared: (() -> Void)?`。配套新增一个 `public struct PromoBlockSelection { let blockID: String; let label: String; let outerHTML: String }`（放 HTMLPreviewKit，供两插件复用）。
- **`WKWebViewConfiguration` 注册 messageHandler**：`config.userContentController.add(Coordinator(), name: "promoBlockAction")`，并把"选中/清除/发送"三种动作经 `WKScriptMessage` 回传。
- **注入一段 JS（`evaluateJavaScript` 在 `load` 完成后执行）**，职责：
  1. `contextmenu` 事件：`event.target.closest('[data-block]')`，有则 `preventDefault()`、给该块加 `.promo-block--active` 描边高亮、在其右上角浮一个绝对定位的小按钮（"💬 发给助手讨论"）；点击非该块区域则取消高亮。
  2. 兼容兜底：若点中的元素没有 `data-block` 祖先，退而向上找最近的 `<section>`/`<div class="screen">`/`<h1>` 等语义块（保证存量/手写 HTML 也能选）。
  3. 浮动按钮点击 → `window.webkit.messageHandlers.promoBlockAction.postMessage({ action:"send", blockID, label, outerHTML: el.outerHTML })`。
  4. 每次选中前先清掉上一个高亮（用一个 module 级变量记 `currentBlock`）。
- **缩放/重载安全**：`HTMLPreviewView` 已对 webview 做 `scaleEffect`（`:59`）。JS 浮层用 `position:absolute` 相对被选块定位，会随 webview 内容一起缩放，无需额外处理。HTML 每次 `loadKey` 变化会重载（`:121-123`），重载后需重新注入 JS —— 在 `updateNSView` 里，当发生重载时（loadKey 变）用 `webView.navigationDelegate` 的 `didFinish` 钩子重新 `evaluateJavaScript`，保证刷新预览后交互仍在。
- 提供一个 `removeAllUserScripts` 时机：旧 webview 重建时清理（`makeNSView` 每次新实例，天然干净）。

> 注：为何把交互做在 HTMLPreviewKit（共享渲染包）而不是插件里——因为 WKWebView 实例在这里创建，JS 必须注入到此实例。插件侧只通过闭包拿结果。

### 3. `Plugins/AppStorePromoDesignerPlugin/.../Services/Runtime.swift` — 持有 kernel 引用
`Runtime` enum 目前只存存储路径，没有 kernel。为让 `PromoDesignerView` 能拿到 `kernel.conversationInput`：
- 新增 `static private(set) var kernel: LumiKernel?`
- `configure(kernel:)` 里加一行 `Runtime.kernel = kernel`
- `reset()` 里加 `kernel = nil`（测试辅助）

（采用 StoryWriter 的 `RuntimeBridge` 模式而非改 `PromoDesignerView` 初始化签名，避免改动 `viewContainers` 闭包和 `PromoDesignerView()` 的无参构造约定。）

### 4. `Plugins/AppStorePromoDesignerPlugin/.../Views/Views.swift` — 接线 + 草稿组装
在 `PromoDesignerView` 的 `HTMLPreviewView(...)` 调用处（`:220`）补两个闭包：
```swift
HTMLPreviewView(
    htmlText: resolved.html,
    fileURL: resolved.htmlURL,
    contentSize: preset.cgSize,
    onBlockSelected: { selection in sendBlockToChat(selection, resolved: resolved) },
    onBlockCleared: nil
)
```
新增私有方法 `sendBlockToChat(_:resolved:)`：
- 组装草稿文本（含上下文，方便 LLM 直接定位修改）：
  ```
  帮我改一下这张促销图的「{label}」区块。

  任务：{task.title}（{task.deviceFamily}）
  图片：{image.title}
  区块标识：{blockID}

  当前该区块的 HTML：
  ```html
  {outerHTML}
  ```
  ```
- 写入输入框（复用 StoryWriter 的追加/覆盖逻辑）：
  ```swift
  guard let input = Runtime.kernel?.conversationInput else { return }
  if input.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      input.text = draft
  } else {
      input.text = input.text.trimmingCharacters(...) + "\n\n" + draft
  }
  input.isInputFocused = true  // 让输入框获得焦点，用户可继续打字补充
  ```
- 这样**符合你要的"填入输入框待发送"**：草稿进输入框、焦点切过去、用户可改可补、回车才真正发送。发送时这条 user 消息正文里就含区块 HTML，LLM 经 `willSendToLLM` 已知可用 `_patch_html` 改这块。

### 5. （轻量）`HTMLPreviewKit` 的 `Package.swift` / 测试
- 确认 `PromoBlockSelection` struct 加了 `public` 可见性。
- 若 HTMLPreviewKit 有单元测试目录，给 JS 选择逻辑加一个最小测试（可选，看现有测试约定）。

## 关键技术校验（已读源码确认）
- ✅ `kernel.conversationInput`（`ConversationInputProviding`）有可写 `text`、`isInputFocused`，`StoryWriterPlugin` 已验证此路径（`StoryOutlineView.swift:235-245`）。
- ✅ `HTMLPreviewView` 已暴露 `onWebViewResolved: ((WKWebView)->Void)?`（`:16`）但插件未用——可作 JS 注入入口；但更干净的做法是新加 `onBlockSelected` 闭包，不破坏现有 API。
- ✅ LLM 修改闭环：`_patch_html`/`_replace_html`（`PromoTools.swift`）→ 落盘 → `WorkspaceStore.shared.reload(...)`（工具内已调用）→ SwiftUI 自动刷新。
- ✅ messageHandler 回传 `outerHTML` 是字符串，无需 base64/图片管线，链路最短。

## 不做的事 / 取舍
- **不新增协议**：`ConversationInputProviding` 已够用，避免无谓的 kernel 改动。
- **不自动发送**：遵循你选的"待发送"，只预填 + 聚焦。
- **不渲染区块缩略图进附件 chip**：草稿里已含 outerHTML 全文，LLM 可读；省掉附件池逻辑。
- **存量无 `data-block` 的 HTML**：JS 兜底按语义块（`<section>`/`<h1>`）选，体验略降但可用；不强制迁移老文件。

## 风险点
1. **JS 注入时机**：`loadFileURL` 异步，需在 `didFinish` 导航回调里注入而非 `makeNSView` 同步执行。计划用 `WKNavigationDelegate`，Coordinator 实现 `webView(_:didFinish:)`。
2. **多实例 webview 的 messageHandler 保留环**：`Coordinator` 作为 `WKScriptMessageHandler` 会持有 webview，需用 weak 或在 `deinit` 里 `removeScriptMessageHandler`，避免内存泄漏（WebKit 常见坑）。
3. **缩放下浮动按钮的可点击性**：`scaleEffect` 是 SwiftUI transform，不影响 webview 内部 hit-testing，按钮可正常点击。

## 验证方式
- 新建一个 promo task → 预览 → 右键标题区 → 看到高亮描边 + 浮动按钮 → 点按钮 → 主聊天输入框出现带区块 HTML 的草稿且获得焦点。
- 继续输入"把标题改成 XXX"→ 回车 → LLM 调 `_patch_html` → 预览自动刷新，标题更新。
- 右键存量（无 `data-block`）HTML → 兜底按 `<section>` 选中。
- 确认无 webview 内存泄漏（切换图片多次）。