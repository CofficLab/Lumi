# 新增「设计师审核」工具（sub-agent 视角评审单张促销图）

## 结论先行
**完全可行，无需新增任何内核基础设施。** 内核的 `LLMProviderManaging.generateText(request, providerID:, model:)` 就是为此设计的"一次性 LLM 调用"API（不写消息库、不触发 turn、不发通知）。工具内部：渲染 PNG → 带 `imageAttachments` 直接调 provider → 拿回设计师视角的审核意见作为 tool content 返回。照搬 `AutoConversationTitleService` 的模式 + `PreviewPromoImageTool` 的渲染逻辑。

## 走向（按你已确认的选择）
- **路径**：直接调用 provider（`generateText`），不开独立 sub-agent 对话。
- **范围**：单张图片，工具参数带 `imageId`，审核当前选中那张。

## 改动文件（共 3 处）

### 1. `Plugins/AppStorePromoDesignerPlugin/.../Tools/PromoTools.swift` — 新增 `ReviewPromoImageTool`
在文件末尾（`LintPromoTaskTool` 之后）新增一个 `public struct ReviewPromoImageTool: LumiAgentTool`，结构与 `PreviewPromoImageTool` 对齐：

```swift
public struct ReviewPromoImageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_review_image",
        displayName: "Review promo image",
        description: "Render a promotional image and ask a senior designer persona to critique it, returning concrete revision suggestions. Read-only; does not modify HTML."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["displayType"] = ["type": "string", "description": "Exact App Store display type. Defaults to the first preset for the task family."]
        properties["focus"] = ["type": "string", "description": "Optional area to focus the critique (e.g. 'typography', 'hierarchy', 'color'). Omit for a full review."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId"]]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String { ... }
}
```

`execute` 内部步骤（每步都有现成先例）：
1. **解析 + 读图 + lint**（复用 `PromoToolSupport.resolveScope`/`storagePath`/`required`/`store.readImage`/`store.lintImage`，照搬 `PreviewPromoImageTool:364-376`）。
2. **渲染 PNG**（`AppStorePromoHTMLExporter.exportPNG(html:fileURL:preset:)`，照搬 `:377`）。
3. **构造附件**：`LumiImageAttachment(mimeType:"image/png", base64Data: data.base64EncodedString(), fileName: ...)`（照搬 `:378`）。
4. **构造 `LumiLLMRequest`**：
   - `messages`: `[设计师人设 system, 带 task/image/display 上下文的 user]`
   - `imageAttachments: [附件]`
   - `model: ""`（让 manager 解析实际模型）、`tools: []`
5. **调 provider**：`let review = try await providerManager.generateText(request, providerID: selectedProviderID, model: selectedModel)`（照搬 `AutoConversationTitleService:160-164` 的 provider/model 解析回退）。
6. **返回**：把 `review`（审核意见正文）作为 tool content 返回。**不调 `kernel.attachImage`**（避免把输入图重复喂给父 turn）。

**设计师人设 prompt**（system message，固定文案，类似 `titlePrompt`）：从资深 App Store 创意设计师视角，针对促销主图（hero/promo）评审——层级/排版/留白、色彩与对比、文案可读性、视觉焦点、品牌一致性、与目标设备尺寸的适配。要求输出结构化：① 总体印象 ② 问题清单（按严重度）③ 具体可执行的修改建议（能直接对应到 HTML 改动）。若 `focus` 参数非空，则聚焦该维度。

**错误兜底**：
- `kernel.llmProvider` 为 nil → 返回提示串 `"Review unavailable: no LLM provider registered."`（不抛错，保持工具可用性）。
- provider 不支持视觉（调用失败）→ catch 后返回错误说明串，不中断父 turn。

### 2. `Plugins/AppStorePromoDesignerPlugin/.../PromoDesignerPlugin.swift` — 注册新工具
- `agentTools(kernel:)`（`:26-40`）的数组末尾加 `ReviewPromoImageTool()`。
- `willSendToLLM`（`:42-52`）的系统提示里补一句：生成/修改图片后，可用 `app_store_promo_review_image` 从设计师视角获取审核意见再迭代。

### 3. 测试 `Plugins/AppStorePromoDesignerPlugin/Tests/.../AppStorePromoDesignerPluginTests.swift`
- 在现有 `contributesOptInWorkspaceAndCompleteToolSet()` 里把工具数断言从 11 改为 12（若该断言按数组长度），并断言新工具 id 存在。
- 由于真实 provider 调用无法在单测里跑，审核逻辑本身只做"工具注册/schema"层面的测试，不测 LLM 调用（符合现有测试边界）。

## 关键技术校验（已读源码确认）
- ✅ `LumiAgentTool.execute` 直接收 `kernel: LumiKernel`，可访问 `kernel.llmProvider`（`LumiAgentTool.swift:164`）。
- ✅ `generateText` 是 `@MainActor async`，工具在 main actor 跑，无冲突（`LLMProviderManaging.swift:122-128`）。
- ✅ `LumiLLMRequest` 支持 `imageAttachments`（`LLMRequest.swift:83`），vision provider 会转 content block（`VisionMessageContentBuilder.swift`）。
- ✅ `AutoConversationTitleService` 是直接调 provider 的现成先例（`:137-166`），含 provider/model 解析回退。
- ✅ `PreviewPromoImageTool` 是渲染+附件构造的现成模板（`:363-380`）。
- ✅ 默认 `riskLevel = .low`、`displayDescription`、`executeResult` 由协议 extension 提供（`LumiAgentTool.swift:170-177`），审核是只读工具，沿用默认即可。
- ✅ 代码库无任何规则禁止工具内部调 LLM；`SubAgentTool` 证明嵌套被主动支持。

## 不做的事 / 取舍
- **不开独立 sub-agent 对话**：你选了直接调用，更轻、不占对话、不污染历史。
- **不自动改 HTML**：审核工具只返回意见，是否改由主 agent/用户决定（保持工具单一职责，`riskLevel=.low`）。
- **不把输入图 attachImage**：避免重复喂给父 turn；审核意见正文已含足够上下文。
- **不批量审**：你选了单张；批量可后续加（工具签名已为可选 `imageId` 预留扩展空间，但本期 `imageId` 必填）。

## 风险点
1. **所选模型不支持视觉**：`generateText` 会抛错。已用 try/catch 兜底为返回错误说明串，不中断父 turn；可在返回串里提示用户切换 vision 模型。
2. **prompt 质量**：审核效果高度依赖设计师人设 prompt。首版用结构化输出约束（总体/问题/建议），后续可按实际效果调。
3. **耗时/成本**：每次审核是一次额外的 vision 调用。单张、按需触发，可接受。

## 验证方式
- 编译通过 + 现有测试过 + 新增工具注册断言过。
- 手动：让 agent 创建一张图 → 调 `app_store_promo_review_image` → 返回结构化审核意见 → agent 据此用 `_patch_html` 迭代。
- 选中一个不支持视觉的模型调用 → 返回友好错误串而非崩溃。