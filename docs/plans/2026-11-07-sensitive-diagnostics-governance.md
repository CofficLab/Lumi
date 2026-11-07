# Sensitive Diagnostics Governance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让 HTTP、工具审计、LLM 原始事件和文件日志默认脱敏且有界，并保证旧数据在导出时也不会绕过治理。

**Architecture:** 在最底层 `ProviderDiagnostics` 提供共享脱敏与有界采集策略，各 Store 在写入前强制执行，导出/staging 再执行一次。功能消息、ToolJob 恢复数据与 Artifact 不使用诊断截断逻辑；大结果 Artifact 化由工具契约专项处理。

**Tech Stack:** Swift 6、Swift Testing、SwiftData、OSLog、ProviderDiagnostics、PluginNetworkManager、ProviderToolManager、KitLLM、PluginFileLog。

---

## 1. 当前问题与边界

### 已确认的事实

- `Packages/PluginNetworkManager/Sources/PluginNetworkManager/Services/HTTPExchangeStore.swift` 的 `begin` 当前直接保存所有 request headers 与 body；两个响应完成入口也保存响应 headers/body。
- `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolCallRecordStore.swift` 当前保存完整 `argumentsJSON` 和 `resultJSON`，仅对 `resultContent` 做字符前缀截断。这些 raw 字段并非纯审计副本：`DefaultToolManagerProviding.toolCallResult` 与 `PluginToolManager/Managers/ToolManager+Run.swift` 会在重启授权后读取它们以避免重复执行，消息列表也用 record 恢复功能渲染。
- `Packages/KitLLM/Sources/KitLLM/Base/VendorLLMProvider.swift` 的 accumulator 可累积 `rawStreamEvents`，最终进入 `LLMResponse.rawStreamEventsJSON`。
- `Packages/PluginFileLog/Sources/PluginFileLog/FileLogCoordinator.swift` 当前写日志行并制作诊断 archive，需要两个治理边界。
- `Packages/ProviderMessage/Sources/ProviderMessage/MessageManaging.swift` 明确区分内存 inserted 与 persisted；功能消息不是诊断记录。

### 非目标

- 不删除或截断 `MessageModel` 的功能正文、tool calls、恢复所需 metadata。
- 不修改 `ToolJobRecordStore` 的功能恢复数据，也不清空 `ToolCallRecordStore` 仍被重启去重、授权恢复和消息渲染读取的 raw 字段。后者在本计划中明确归类为**功能结果快照**；只把设置页执行日志、诊断导出等审计消费者迁移到 metadata-only `ToolAuditEvent`。未来若要删除这些 raw 字段，必须先另立功能结果 Store 并迁移全部读取方，不属于本计划。
- 不增加“查看完整敏感正文”的设置 UI，不实现远程日志上报。
- 不承诺正则能识别任意格式的所有秘密。主要防线是默认不采集正文和敏感字段，文本 redactor 是第二道防线。
- 不在本计划实现 Artifact、Trace 或 ConversationInput。

## 2. 共享契约

在 `ProviderDiagnostics` 新建以下值类型。字段和默认值可按现有代码风格微调，但语义不能减弱。

```swift
public struct SensitiveDiagnosticsPolicy: Sendable, Equatable {
    public enum BodyMode: String, Sendable {
        case none
        case redactedBounded
    }

    public var bodyMode: BodyMode = .none
    public var maxMetadataBytes: Int = 16 * 1024
    public var maxBodyBytes: Int = 64 * 1024
    public var maxLogLineBytes: Int = 16 * 1024

    public static let `default` = Self()

    public init(
        bodyMode: BodyMode = .none,
        maxMetadataBytes: Int = 16 * 1024,
        maxBodyBytes: Int = 64 * 1024,
        maxLogLineBytes: Int = 16 * 1024
    ) { /* validate non-negative; assign */ }
}

public struct BoundedDiagnosticCapture: Sendable, Equatable {
    public let text: String?
    public let originalByteCount: Int
    public let capturedByteCount: Int
    public let isTruncated: Bool
    public let suppressionReason: String?

    public static func capture(
        _ data: Data?,
        policy: SensitiveDiagnosticsPolicy
    ) -> Self { /* nil/empty, none, redactedBounded */ }
}
```

`redact(text:)` 至少覆盖：

- `Authorization` / `Proxy-Authorization` 的 Basic、Bearer 与任意非空值。
- `Cookie` / `Set-Cookie`。
- `api_key`、`api-key`、`apikey`、`access_token`、`refresh_token`、`id_token`、`password`、`secret`、`client_secret` 的 JSON、form 与 key=value 形式。
- URL 中上述敏感 query 参数；剥离 userinfo。
- 独立 Bearer token。

使用固定替换文本 `<redacted>`，不能保留 secret 的前缀/后缀。`String(decoding: prefixBytes, as: UTF8.self)` 用于按 UTF-8 字节截断；预算和计数必须按字节，不按 `Character`。

HTTP headers 使用 allowlist，而不是 denylist：

```text
accept, content-type, content-length, cache-control, etag, last-modified,
retry-after, request-id, x-request-id, date, server
```

即使 header 名在 allowlist 中，值仍经过 `redact(text:)`。其他 header 不保存值；如需保留排障信息，只保存 `suppressedHeaderNames` 的排序名单和总数量。

## 3. Task 1：共享策略与有界采集

**Files:**

- Modify: `Packages/ProviderDiagnostics/Sources/ProviderDiagnostics/DiagnosticsProviding.swift` only if the existing public entry needs documentation
- Create: `Packages/ProviderDiagnostics/Sources/ProviderDiagnostics/SensitiveDiagnosticsPolicy.swift`
- Create: `Packages/ProviderDiagnostics/Sources/ProviderDiagnostics/BoundedDiagnosticCapture.swift`
- Test: `Packages/ProviderDiagnostics/Tests/ProviderDiagnosticsTests/SensitiveDiagnosticsPolicyTests.swift`
- Test: `Packages/ProviderDiagnostics/Tests/ProviderDiagnosticsTests/BoundedDiagnosticCaptureTests.swift`

### Step 1：写失败测试

用 Swift Testing 覆盖：

1. `.default.bodyMode == .none`，任意 body 返回 `text == nil`、`suppressionReason == "metadata_only"`，保留真实 original byte count。
2. `.redactedBounded` 对 100KB 输入只保存 64KB，并设置 `isTruncated`。
3. Unicode 多字节文本不崩溃，captured bytes 不超预算。
4. JSON `{"access_token":"test-secret-do-not-use"}`、Bearer、Cookie、form password、嵌套 URL query 均不含 secret。
5. 普通文本 `status=ok` 与 request ID 原样保留。
6. 空/nil body 与 already-empty body 的计数正确。

核心断言示意：

```swift
let captured = BoundedDiagnosticCapture.capture(
    Data(#"{"access_token":"test-secret-do-not-use"}"#.utf8),
    policy: SensitiveDiagnosticsPolicy(bodyMode: .redactedBounded)
)
#expect(captured.text?.contains("test-secret-do-not-use") == false)
#expect(captured.text?.contains("<redacted>") == true)
#expect(captured.originalByteCount > captured.capturedByteCount || !captured.isTruncated)
```

最后一条不要写成永远为真的断言；为短输入和长输入分别写明确预期。

### Step 2：确认测试失败

```bash
swift test --package-path Packages/ProviderDiagnostics --filter SensitiveDiagnosticsPolicyTests
swift test --package-path Packages/ProviderDiagnostics --filter BoundedDiagnosticCaptureTests
```

预期：新类型不存在而编译失败，或默认行为断言失败。若编译失败，记录为预期 RED，再进入最小实现。

### Step 3：最小实现

实现纯值类型，无文件、网络、全局可变配置。文本 redaction 顺序必须避免二次替换破坏 `<redacted>`；URL 先用 `URLComponents` 处理 query/userinfo，再处理剩余 key/value。

### Step 4：确认通过

重复两条命令，预期全部 PASS；再运行：

```bash
swift test --package-path Packages/ProviderDiagnostics
```

### Step 5：独立提交

```bash
git add Packages/ProviderDiagnostics
git diff --cached --check
git commit -m "feat(ProviderDiagnostics): add bounded sensitive capture policy"
```

## 4. Task 2：HTTP 入库边界强制 metadata-only

**Files:**

- Modify: `Packages/PluginNetworkManager/Package.swift`
- Create: `Packages/PluginNetworkManager/Sources/PluginNetworkManager/Support/HTTPExchangeSanitizer.swift`
- Modify: `Packages/PluginNetworkManager/Sources/PluginNetworkManager/Services/HTTPExchangeStore.swift` (`begin`, `finishRecord`, `finish`)
- Modify: `Packages/PluginNetworkManager/Sources/PluginNetworkManager/Models/HTTPExchangeRecord.swift` only if capture metadata fields are required
- Test: `Packages/PluginNetworkManager/Tests/PluginNetworkManagerTests/HTTPExchangeSanitizerTests.swift`
- Test: `Packages/PluginNetworkManager/Tests/PluginNetworkManagerTests/HTTPExchangeStoreTests.swift`

### Step 1：写失败测试

建立临时目录 Store，构造带以下内容的 `URLRequest`：

- `Authorization: Bearer test-secret-do-not-use`
- `Cookie: session=test-session-do-not-use`
- URL `https://example.invalid/v1/chat?access_token=test-secret-do-not-use&model=test`
- JSON body 含 prompt 和 token。

调用 `begin` 后从数据库读取真实记录并断言：

- `requestBody == nil`。
- Authorization/Cookie 的值没有进入任何持久字段。
- URL 不含敏感 query 和 userinfo，仍保留 host/path 与非敏感 `model=test`。
- allowlist headers 可用，suppressed names/count 可用。
- request body 的 original byte count 与 capture mode 可从 details/metadata 读取。

对 `finishRecord` 和 `finish` 各写一个响应测试，防止只修一个入口。响应默认 body 也为 nil，Set-Cookie 不入库。

### Step 2：确认测试失败

```bash
swift test --package-path Packages/PluginNetworkManager --filter HTTPExchangeSanitizerTests
swift test --package-path Packages/PluginNetworkManager --filter HTTPExchangeStoreTests
```

预期：当前原始 header/body 被保存，敏感断言 RED。

### Step 3：最小实现

`HTTPExchangeSanitizer` 输出一个纯值快照，Store 只接收该快照：

```swift
struct SanitizedHTTPExchange: Sendable, Equatable {
    let url: String
    let headersJSON: Data
    let body: Data?
    let details: [String: String]
}
```

在 `Package.swift` 添加 `ProviderDiagnostics` 本地 package 和 target product 依赖。`begin` 先 sanitize，再构造 `HTTPExchangeRecord`；两个响应入口共用同一个 `applySanitizedResponse` private helper。不要只修改 UI formatter。

如果为 `captureMode`、`requestBodyByteCount`、`responseBodyByteCount` 增加模型字段，全部设默认值并验证轻量迁移；也可以把这些值放进现有 details JSON，避免无必要 schema 变更。

### Step 4：确认通过与旧功能不回归

```bash
swift test --package-path Packages/PluginNetworkManager
```

预期：新安全测试和现有分页、retention、retry、UI formatter 测试全部 PASS。设置页仍可按 method/host/status 搜索，但 body 显示“未采集”，不能显示成真实空响应。

### Step 5：独立提交

```bash
git add Packages/PluginNetworkManager/Package.swift Packages/PluginNetworkManager/Sources/PluginNetworkManager Packages/PluginNetworkManager/Tests/PluginNetworkManagerTests
git diff --cached --check
git commit -m "fix(PluginNetworkManager): sanitize HTTP diagnostics before persistence"
```

## 5. Task 3：把工具执行日志改为独立审计事件

**Files:**

- Modify: `Packages/ProviderToolManager/Package.swift`
- Create: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolAuditEvent.swift`
- Modify: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolCallRecordModel.swift`
- Modify: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolCallRecordStore.swift`
- Modify: `Packages/ProviderToolManager/Sources/ProviderToolManager/DefaultToolManagerProviding.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolExecutionManager.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Managers/ToolManager+Run.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Capabilities/ToolManagerCapability.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/ViewModels/ToolManagerViewModel.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Views/ToolCallLogListView.swift`
- Modify: `Packages/PluginToolManager/Sources/PluginToolManager/Views/ToolCallRecordDetailView.swift`
- Test: `Packages/ProviderToolManager/Tests/ProviderToolManagerTests/ToolAuditEventTests.swift`
- Test: `Packages/ProviderToolManager/Tests/ProviderToolManagerTests/ToolCallRecordStoreTests.swift`
- Test: `Packages/ProviderToolManager/Tests/ProviderToolManagerTests/DefaultToolManagerProvidingTests.swift`
- Test: `Packages/PluginToolManager/Tests/PluginToolManagerTests/ToolExecutionManagerTests.swift`

### Step 1：写失败测试

测试工具参数和结果均含虚构 token、文件正文和大文本。执行完成后分别读取**功能结果**与**审计事件**，断言：

- 原始 token、参数正文、结果正文均不在 `ToolAuditEvent`、设置页执行日志或其诊断导出中。
- 审计保留 tool name、IDs、时间、风险、success/error、duration、原始/返回字节数、截断状态、Artifact 数量。
- `ToolJobRecordStore` 与 `ToolCallRecordStore` 中用于恢复的原始数据保持原行为，单独写测试证明没有被本 Task 误改。
- 两个 ToolManager 用新 Store 重建后，`toolCallResult` 仍返回完整结果；再次 `executeAuthorized` 直接复用结果，fake 写工具 execute 次数保持 0，证明不会重跑副作用。
- PluginToolManager 与 DefaultToolManagerProviding 两条路径都生成同一种 metadata-only 审计事件；现有 `toolCalls(for:)` 功能渲染投影仍能恢复结果正文。

建议事件形状：

```swift
public struct ToolAuditEvent: Identifiable, Sendable, Equatable {
    public let id: String
    public let toolCallID: String
    public let conversationID: UUID
    public let turnID: UUID?
    public let traceID: UUID?
    public let spanID: UUID?
    public let toolName: String
    public let toolDisplayName: String
    public let createdAt: Date
    public let startedAt: Date
    public let completedAt: Date?
    public let outcome: String
    public let riskLevel: String
    public let argumentsByteCount: Int
    public let resultByteCount: Int
    public let resultWasTruncated: Bool
    public let artifactCount: Int
    public let errorCode: String?
}
```

Trace 字段在工具契约专项接入前可为 nil，但类型先预留，不保存原始 arguments/result。

### Step 2：确认测试失败

```bash
swift test --package-path Packages/ProviderToolManager --filter ToolAuditEventTests
swift test --package-path Packages/ProviderToolManager --filter ToolCallRecordStoreTests
swift test --package-path Packages/ProviderToolManager --filter DefaultToolManagerProvidingTests
swift test --package-path Packages/PluginToolManager --filter ToolExecutionManagerTests
```

预期：设置页仍读取完整 arguments/result，新审计接口不存在；重启不重跑测试应先守住当前功能行为，若失败说明现有恢复路径也需先修复。

### Step 3：最小实现

- `ToolCallRecordStore.record` 继续写功能结果快照，raw columns **不得清空**。新增 `fetchAuditPage` 只返回 `ToolAuditEvent`；字节数等 metadata 在新写入时落可选/默认字段，legacy 记录可在投影时从 raw 计算计数，但不能把 raw 带入事件。
- 设置页 `fetchLogPage`、ViewModel、列表和详情一次性改用 `ToolAuditEvent`，详情显示“参数/结果正文未采集”和字节数，不再接收含 raw 的 `ToolCallRecord`。诊断导出也只编码此事件。
- `toolCalls(for:)` / `toolCalls(forTurnIDs:)` 与 `toolCallResult` 仍是功能接口，消息列表和重启授权继续使用完整 `ToolCallRecord`；不得把它们改成 metadata-only，也不得用空字符串冒充真实结果。
- 对 legacy 模型新增字段使用可选值或默认值，保证旧数据库可打开。
- 不在 ToolExecutionManager 内重新实现一套审计；它调用同一 Provider 能力。错误映射只保存稳定错误码/类型，不保存可能含 secret 的 `localizedDescription` 全文。

### Step 4：确认通过

```bash
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginToolManager
swift test --package-path Packages/PluginMessageListStandard
swift test --package-path Packages/PluginMessageListDetailed
```

并检查执行日志 UI：可看到“参数正文未采集”和字节数，不显示伪造的 `{}` 结果；随后实际重启并再次批准同一历史写工具，确认只恢复结果、不再次修改文件。

### Step 5：独立提交

```bash
git add Packages/ProviderToolManager Packages/PluginToolManager
git diff --cached --check
git commit -m "refactor(ProviderToolManager): persist metadata-only tool audit events"
```

## 6. Task 4：默认停止累积 LLM raw stream / raw response

**Files:**

- Modify: `Packages/KitLLM/Package.swift` only if it imports ProviderDiagnostics
- Modify: `Packages/KitLLM/Sources/KitLLM/Base/VendorLLMProvider.swift`
- Modify: `Packages/KitLLM/Sources/KitLLM/Core/LLMTypes.swift` only to document/default diagnostic capture
- Test: `Packages/KitLLM/Tests/KitLLMTests/KitLLMTests.swift` or a focused new `RawStreamDiagnosticCaptureTests.swift`

### Step 1：写失败测试

用 fragmented SSE fixture 验证：

1. 默认 accumulator 不保留 raw event JSON，`rawStreamEventsJSON == nil`。
2. content、reasoning、完整 tool calls、usage、stopReason 与之前完全一致。
3. malformed JSON 仍产生既有协议错误，不因关闭诊断而吞错。
4. 显式测试 opt-in 时才产生 redacted/bounded raw capture；超过预算停止追加，而不是先保存全部再截断。
5. `fetchMessagesForLLMContext` 不需要 raw 列的行为不回归（该测试可放 MessageManager 包，不重复实现）。

### Step 2：确认失败

```bash
swift test --package-path Packages/KitLLM --filter RawStreamDiagnosticCaptureTests
```

预期：默认路径仍累积 raw events，或 capture policy 类型不存在。

### Step 3：最小实现

给 accumulator 增加默认 `.none` 的 capture 配置；在事件进入 raw buffer 之前判断预算和模式。`content/toolCalls` 累积器不得读取该配置。若 raw response 也仅用于诊断，同样默认 nil；若存在功能调用方，先列出调用方并迁移，不能直接删除功能数据。

不提供全局环境变量绕过。测试 opt-in 通过 initializer 注入，生产默认保持关闭。

### Step 4：确认通过

```bash
swift test --package-path Packages/KitLLM
swift test --package-path Packages/PluginLLMManager
swift test --package-path Packages/PluginMessageManager
```

### Step 5：独立提交

```bash
git add Packages/KitLLM Packages/PluginLLMManager Packages/PluginMessageManager
git diff --cached --check
git commit -m "fix(KitLLM): disable raw stream diagnostic capture by default"
```

只暂存实际修改的包；未改的不要加入提交。

## 7. Task 5：文件日志写盘与 archive staging 双重治理

**Files:**

- Modify: `Packages/PluginFileLog/Package.swift`
- Create: `Packages/PluginFileLog/Sources/PluginFileLog/FileLogRecordSanitizer.swift`
- Modify: `Packages/PluginFileLog/Sources/PluginFileLog/FileLogCoordinator.swift`
- Test: `Packages/PluginFileLog/Tests/PluginFileLogTests/FileLogRecordSanitizerTests.swift`
- Test: `Packages/PluginFileLog/Tests/PluginFileLogTests/FileLogCoordinatorTests.swift`

### Step 1：写失败测试

- 高风险 category（LLM prompt/response、HTTP body、tool arguments/result）默认只保留类别、时间、级别和字节数，正文被抑制。
- 普通日志中的 Bearer、token=key、password JSON 被 redacted。
- 单行按 UTF-8 字节预算截断，rotation 行为不变。
- 在 staging 目录放入模拟旧日志，archive 前再次 sanitizer，最终 staging 文件不含 secret。
- 不把 secret 写进测试失败消息或真实用户日志目录。

### Step 2：确认失败

```bash
swift test --package-path Packages/PluginFileLog --filter FileLogRecordSanitizerTests
swift test --package-path Packages/PluginFileLog --filter FileLogCoordinatorTests
```

### Step 3：最小实现

`writePendingRecords` 在 `writeData` 前调用 sanitizer；`makeDiagnosticsArchiveOnQueue` 对每个复制到 staging 的文本日志再调用 sanitizer。二进制或未知文件默认不放入 archive，除非已有明确安全类型。

保留现有 polling、rotation、zip 实现，不重写文件日志系统。

### Step 4：确认通过

```bash
swift test --package-path Packages/PluginFileLog
```

### Step 5：独立提交

```bash
git add Packages/PluginFileLog
git diff --cached --check
git commit -m "fix(PluginFileLog): sanitize persisted and exported log records"
```

## 8. Task 6：旧记录分批清理与导出二次脱敏

**Files:**

- Create: `Packages/PluginNetworkManager/Sources/PluginNetworkManager/Support/LegacyHTTPDiagnosticScrubber.swift`
- Modify: `Packages/PluginNetworkManager/Sources/PluginNetworkManager/Services/HTTPExchangeStore.swift`
- Modify: `Packages/PluginNetworkManager/Sources/PluginNetworkManager/Support/HTTPExchangeExportFormatter.swift`
- Modify: `Packages/ProviderToolManager/Sources/ProviderToolManager/ToolCallRecordStore.swift`
- Modify: `Packages/PluginFileLog/Sources/PluginFileLog/FileLogCoordinator.swift`
- Test: `Packages/PluginNetworkManager/Tests/PluginNetworkManagerTests/LegacyHTTPDiagnosticScrubberTests.swift`
- Test: `Packages/PluginNetworkManager/Tests/PluginNetworkManagerTests/HTTPExchangeExportFormatterTests.swift`
- Test: `Packages/ProviderToolManager/Tests/ProviderToolManagerTests/ToolCallRecordStoreTests.swift`

### Step 1：写失败测试

- 构造 legacy HTTP 记录，运行单批 scrub 后 raw body 为 nil、敏感 header/query 被清理，method/host/status/time 保留。
- 每批最多 100 条；中途注入 save 失败，已提交批次不回退，下批可重试，不显示“全部完成”。
- 导出未经 scrub 的旧记录时，formatter 仍再次 sanitize。
- legacy ToolCallRecord 经审计分页/导出后只暴露 metadata，raw arguments/result 不进入 `ToolAuditEvent` 或诊断导出；raw 功能字段本身保持逐字节不变。
- 对 legacy 写工具完成记录重建两个 ToolManager，重启授权仍复用原结果且 execute 次数为 0；本 Task 任何 scrub 都不得使该测试失效。
- migration marker 只能在整库扫描成功后推进；重复运行幂等。

### Step 2：确认失败

```bash
swift test --package-path Packages/PluginNetworkManager --filter LegacyHTTPDiagnosticScrubberTests
swift test --package-path Packages/PluginNetworkManager --filter HTTPExchangeExportFormatterTests
swift test --package-path Packages/ProviderToolManager --filter ToolCallRecordStoreTests
```

### Step 3：最小实现

- 后台分批处理，每批独立 `ModelContext` 和 `save()`；不阻塞 MainActor，不一次物化全库。
- marker 记录 schema/policy version 与最后完成批次，不记录 secret。
- 对无法安全解析的旧 header JSON，采取 drop，而不是原样保留。
- export 不信任“已 scrub”标记，始终再走同一 sanitizer。
- 不物理删除消息数据库、不执行全库重建、不触碰 ToolJob 功能记录，也不 scrub `ToolCallRecordModel.argumentsJSON/resultContent/resultJSON`。工具侧本 Task 只验证审计投影和导出边界；功能 raw 的删除必须等待独立功能结果 Store 迁移专项。

### Step 4：确认通过

```bash
swift test --package-path Packages/PluginNetworkManager
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginFileLog
```

### Step 5：独立提交

```bash
git add Packages/PluginNetworkManager Packages/ProviderToolManager Packages/PluginFileLog
git diff --cached --check
git commit -m "fix(diagnostics): scrub legacy records before export"
```

## 9. 故障注入矩阵

| 场景 | 预期 |
|---|---|
| sanitizer 遇到非法 UTF-8 | 用安全替换或 suppress，不崩溃，不保存原始 bytes |
| headers JSON 无法解析 | 整个 headers 字段被清理，只保留 suppressed metadata |
| body 正好等于/超过预算 1 字节 | 边界计数准确，无 off-by-one |
| legacy scrub 第 2 批失败 | 第 1 批保持清理，marker 不宣称全量完成，重启可继续 |
| export 绕过最新 scrub | formatter 二次 sanitizer 仍阻止 secret |
| raw stream capture 达到预算 | 停止 raw 追加，content/tool calls 继续完整累积 |
| file log 一行含多个 secret | 全部 redacted，行长仍受限 |
| ToolJob / ToolCallRecord 恢复读取 | 功能参数/结果不受审计治理影响，重启授权不重跑副作用 |

## 10. 验收与真实 App 验证

### 自动测试

```bash
swift test --package-path Packages/ProviderDiagnostics
swift test --package-path Packages/PluginNetworkManager
swift test --package-path Packages/ProviderToolManager
swift test --package-path Packages/PluginToolManager
swift test --package-path Packages/KitLLM
swift test --package-path Packages/PluginLLMManager
swift test --package-path Packages/PluginFileLog
swift test --package-path Packages/PluginMessageManager
```

再运行以下命令；在测试治理 Task 4 前，当前脚本会对失败包仍退出 0，因此必须额外断言失败清单为空：

```bash
Scripts/run-all-package-tests.sh
test ! -s .test-logs/FAILED.txt
```

若有既存失败，逐项与 base 对比，不把失败笼统归为“无关”。

### 手工验证

1. 在测试环境使用虚构 token 发一次 LLM 请求，产生请求、响应、工具调用和文件日志。
2. 打开网络诊断与工具执行日志：能看到时间、URL path、状态、字节数、错误与 trace 字段，正文显示未采集。
3. 检查实际持久化 HTTP 诊断、raw stream 与文件日志，虚构 token、Cookie、prompt 不存在；工具执行日志和审计导出也不含工具正文。功能结果快照可以为重启去重保留 raw，但只能经功能接口读取，不能进入审计事件或诊断包。
4. 导出诊断包，在 staging 和最终 zip 解包后的文本中搜索同一虚构 token，结果为零。
5. 正常对话、工具授权、消息渲染和 Resume 功能不回归；重启后再次授权已完成的写工具不会再次执行。
6. 旧版本消息库与工具记录库能打开； scrub 分批执行期间 UI 保持可交互。

### 完成定义

- 默认配置下，任何新增 HTTP body、raw stream、工具审计正文均为 nil/空且有明确 suppression metadata。
- 所有敏感字段在 Store 入口已处理，导出再次处理。
- 功能消息、ToolJob 和 ToolCallRecord 恢复数据未被误删，重启授权去重测试有实际证据。
- 测试、手工检查与导出扫描都有实际证据。
