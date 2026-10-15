# PluginLLMProviderUITest

UI 测试专用的确定性 LLM 供应商（**仅 DEBUG**）。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## 存在理由

真实供应商在 UI 测试里有三个不可控因素：网络、用户 API Key、模型自身的
不确定性（回复内容与长度不可预期）。这三个因素会让「点击发送后界面应该变成
什么样」这类断言无法写死，只能退化成「好像开始请求了」这种弱断言。

本供应商消除它们：字节流由桩决定、Key 是固定串、回复内容由模型名决定。
测试因此可以断言**具体的界面终态**。

## 设计：模型名承载行为

不为每个测试场景注册一个供应商，而是让**模型名本身决定桩的行为**。
测试通过「选中哪个模型」控制 App 的对话行为。

| 模型 | 行为 | 用途 |
|---|---|---|
| `ui-test-text` | 固定文本，分 3 个 SSE 事件增量吐出 | 正常回合的渲染（**默认模型**） |
| `ui-test-tool` | 一个工具调用，arguments 分两片下发 | 工具执行链路与结果回传 |
| `ui-test-error` | 单个 `error` 事件 | 错误消息渲染与「重试该回合」 |
| `ui-test-slow` | 同文本，段间 sleep 0.4s | 流式加载态 |
| `ui-test-long` | 40 段正文 | 消息列表滚动与虚拟化 |
| `ui-test-unknown` | 兜底（等价于 text） | 未注册模型的降级 |

这与真实供应商用法完全一致：测试点模型选择器 → 选中 `ui-test-error`
就得到一个确定失败的回合，不需要任何测试专属的 UI 分支。

新增场景只需在 `UITestScenario` 加一个 case 并登记模型元数据，
不改插件装配、桩网络或任何生产代码。

## 桩的位置：传输层，不是供应商层

桩只替换 `LLMNetworkProviding`（最底层字节传输），**不** override
`complete(_:)` / `streamComplete(_:onChunk:)`。因此一次「模型回复」仍会走完：

1. `OpenAICompatibleProviderAdapter.buildStreamingRequestBody` —— 真实请求序列化
2. `VendorAPIService.sendStreamingChatRequest` —— 真实事件分发与重试判定
3. `OpenAICompatibleProviderAdapter.parseStreamChunk` —— 真实 SSE 解析
4. `StreamingAccumulator` —— 真实增量累积与终止判定

只有「字节从哪来」是假的。适配器本身有 bug 时测试会失败，而不是被绕过。

桩从**真实序列化后的请求体**里读 `model` 字段决定场景。若适配器把请求体
序列化错了，桩会落到 `.unknown` 场景并产出可辨识输出——这让「桩坏了」和
「适配器坏了」有明确分界。

## 与 MiniMax 夹具的关系（互补，不是替代）

| | MiniMax 夹具 | 本包 |
|---|---|---|
| 桩的位置 | 传输层（`StubNetwork`） | 传输层（`UITestStubNetwork`） |
| 供应商实例 | **真实** `MiniMaxOpenAIProvider` | 替换为 `UITestProvider` |
| 覆盖 | 供应商自身特性：远程模型池刷新、合并策略 | AgentLoop → 消息渲染 → 工具执行 |
| 启动参数 | `--lumi-ui-testing` | `--lumi-ui-testing`（共用） |

两者共用同一启动参数，可同时生效。

## 双重 gate

1. 类体整体包在 `#if DEBUG` 里 → Release 构建中**本插件根本不存在**。
2. 运行时再叠启动参数 gate → 开发者日常 Debug 运行看不到这个供应商。

插件 metadata 的 `policy: .disabled` 进一步确保它无法被用户在设置里手工启用
（避免有人打开一个永远返回假数据的供应商）。

## 选中态处理

UI 测试需要**确定的**供应商，而非「用户上次选的那个」。

- `CustomLLMManager` 的选中态持久化在 `UserDefaults.standard`，而
  `--lumi-ui-testing-isolated-storage` 只隔离数据目录，**不隔离 UserDefaults**。
  插件注册后立刻强制选中 `ui-test-text`，避免回落到真实供应商并发真实请求。
- `order = 900` 让强制选中成为最后生效的那次；此后其他供应商注册时的
  `ensureValidSelection` 不会覆盖有效选中值。
- 反向污染由 `clearStaleSelection()` 兜底：非测试启动时若发现选中态还指向
  `ui-test`，主动改选到首个可用供应商。

## API Key

`resolveAPIKey()` 被 override 为返回固定串 `ui-test-key`，**完全不碰 Keychain**。
真实供应商读 Keychain 在测试环境下可能弹权限授权框阻塞 UI 测试，
或在未配置 Key 时稳定失败。`setApiKey` / `removeApiKey` 是 no-op。

> 这要求 `VendorLLMProvider` 的五个 Keychain 方法声明为 `open` 而非 `public`
> （见 `Packages/KitLLM/Sources/KitLLM/Base/VendorLLMProvider.swift`）。

## Testing

```sh
swift test
```

24 个测试，分三组：

- `UITestStubPayloadTests`：锁定桩产出的 SSE 事件块格式。这让 UI 测试失败时
  能立刻区分「桩写错了」与「生产链路有 bug」。
- `UITestProviderTests`：桩经**真实**适配器链路后的端到端行为。
- `UITestProviderPluginTests`：插件装配与 gate 行为。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../PluginLLMProviderUITest"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginLLMProviderUITest"]),
]
```
