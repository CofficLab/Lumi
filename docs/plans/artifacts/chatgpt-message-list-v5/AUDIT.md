# ChatGPT 消息列表 V5 —— 最终审计报告

- **插件**：`PluginMessageListChatGPT`
- **插件 ID**：`com.coffic.lumi.plugin.message-list.chatgpt`
- **详细度**：`ResponseVerbosity.chatGPT`（持久化值 `"v5"`）
- **ChatSection 槽位**：`exclusiveGroup == "message-list"`，`order == 82`
- **实施范围**：方案 Task 4 – Task 10（Task 1 – 3 由既有提交 `481f6af68` 完成）

---

## 1. 提交清单

| # | 提交 | 内容 |
|---|---|---|
| 1 | `d9961dd9ab` | Renderer 六个 ChatGPT 私有组件 + `.chatGPT` 路由分支 |
| 2 | `d1109ef29` | KitMarkdown 表格横滚 + V5 Markdown 主题 |
| 3 | `aeca48eeb` | 新包分层：Capabilities / Models / Services / ViewModels |
| 4 | `e157750790` | 滚动所有权：reducer + 来源分类器 + tracker + 首屏 gate |
| 5 | `49c9a2f8d9` | 开启真实流式并锁定性能 |
| 6 | `73953c0a30` | 无障碍、本地化、Reduced Motion |
| 7 | `753101a680` | UI 夹具、XCUITest、端到端集成测试、截图索引 |

---

## 2. 验收标准逐条核对

### 2.1 功能验收

| 标准 | 结果 | 证据 |
|---|---|---|
| 设置中出现 ChatGPT V5，默认仍 Standard；`v5` 持久化往返稳定 | ✅ | `ResponseVerbosity.chatGPT` rawValue `"v5"`，alias `"chatgpt"`；`ResponseVerbosityTests` 覆盖；`PluginConversationVerbosity` 文案四语言；`ConversationManagerPreferenceTests` 13 tests 绿（含 `setGlobalVerbosity(.chatGPT)` → 重启后仍为 `.chatGPT`） |
| 任一时刻最多一个 active message-list；V1–V5 往返无空白和双列表 | ✅ | `MessageListSlotArbitrationTests` 11 tests 绿（V1→V2→V3→V4→V5→V1 往返，active 至多一个）；`ChatGPTMessageListEndToEndTests` 验证 V5 槽位接管与其它详细度不抢槽 |
| 内容列、用户气泡、助手正文、轮尾操作符合第 2 节几何合同 | ✅ | `ChatGPTConversationLayout`（768 最大宽 / 16·24 padding / 92%·80% 气泡 / 圆角 18 / 行高 24 / 操作栏 32 / 按钮 28 / 回到底部 32 / 容差 48）由 `ChatGPTConversationLayoutTests` 逐值锁定 |
| 附件、Markdown、代码、表格、reasoning、工具、错误都有真实数据路径 | ✅ | 渲染器路由矩阵测试（user / assistant / tool-step-group / error / status / system / compact / retry / model-switch / default）；`ChatGPTTableLayoutTests`；附件沿用 `cachedDecodedAttachments` 与 `CollapsedContentChips` |
| 复制、再次发送、失败重试语义不混淆；无编辑/分支/点赞/通用重生成的假按钮 | ✅ | 用户复制 + 再次发送走 `ChatGPTUserMessageActions.resend`（调用既有 `resendMessage`，只调用一次）；失败重试只由 `ChatGPTAssistantTextStyle.retryableTurnID` 在 `canRetryTurn == true` 时给出；成功回复**不**出现重试（`ChatGPTAssistantMessageViewTests` 覆盖） |
| V5 真实流式可见，最终 delta 不丢失；无 Provider 时不伪造流式 | ✅ | 插件入口注入 `streamingDisplayEnabled: true`（**仅 V5**）；`ChatGPTStreamingTests` 覆盖：流式只进 live tail、end 及时 flush、无 Provider 时只显示真实 activity、开关关闭时不产生逐字行 |
| V1–V4 视觉、交互和持久化行为不变 | ✅ | `MarkdownTheme.standard` / `.zcode` 逐字段未改（`ZCodeChatMarkdownThemeTests`、`ChatGPTChatMarkdownThemeTests` 双向断言）；`MessageRendererPlugin` 只**新增** `.chatGPT` 分支，`order` 与注册顺序未变；`preferredRendererID` 仍优先（`ChatGPTMessageRoutingTests`） |

### 2.2 性能与滚动验收

| 标准 | 结果 | 证据 |
|---|---|---|
| List cell 复用、有界分页、tail backfill、首屏 gate 均有效 | ✅ | 使用 SwiftUI `List`（**未**改成 `ScrollView + LazyVStack`）；`MessageListPaginationService` pageSize 40 / retained 300；`backfillGap` 逐页回填空档；`InitialPositionGate` 超时兜底放行 |
| streaming 不导致历史 O(n) 重建；等长正文替换仍刷新 | ✅ | `ChatGPTTurnProjectionStore.historyRebuildCount` 断言：100 行历史 + 50 次流式快照 → rebuild 仍为 1；等长 `AAAA → BBBB` 触发重建且复制文本更新（FNV-1a 内容哈希，非长度） |
| 40+ 轮富文本连续 streaming 无持续主线程 100% CPU 与 AttributeGraph 活锁 | ⚠️ **未在真实 App 上实测** | 结构性保证已就位：帧门禁 16ms 合并、live tail 独立轮次、`KitMarkdown` 稳定前缀增量解析。**但**本机 UI 自动化宿主无法初始化（见 §4），无法跑 5 秒连续 streaming 采样。**不宣称已验证** |
| 600 轮 / 1200 条消息在既有 6 秒 mask 预算内完成首屏 | ⚠️ **未在真实 App 上实测** | 首屏 gate 预算 3 秒 + UI 预算 6 秒的结构已就位（`InitialPositionGateTests` 覆盖超时放行）；真实耗时需 UI 自动化恢复后实测。**不宣称已验证** |
| 用户离底后不被 streaming、测高、折叠或 resize 抢回；prepend 保持锚点 | ✅ | `ChatGPTScrollAnchor`：只有 `.user` 来源能改 `following`；`contentChangeAction()` 在 detached 时返回 `.hold`；`ChatGPTScrollSourceClassifier` 把 documentFrameChange / liveResize / layout 归为 `.layout`；prepend 后 `pinToAnchor` 钉回原首条 |

### 2.3 可访问性与安全验收

| 标准 | 结果 | 证据 |
|---|---|---|
| 所有动作可用键盘和 VoiceOver 到达，不依赖 hover | ✅ | 图标按钮均 `.focusable()` + `.focused()` + `accessibilityLabel` + 稳定 identifier；操作栏用**常驻占位 + 透明度**而非条件插入（键盘 focus 可达，且 hover 不引起行高跳动） |
| 不逐 token announcement、不抢焦点；Reduced Motion 下信息完整 | ✅ | 流式无 cursor / 淡入 / 脉冲；`ChatGPTRendererAccessibilityTests` 覆盖；`ChatGPTMotion` / `ChatGPTRendererMotion` 在 Reduced Motion 或全局禁用动画时关闭淡入、位移与 shimmer |
| 工具授权可见且只有一份 bottomFixed 审批 | ✅ | 工具组用**真实** `ToolCallRowView`（含授权状态与结果补全），不复制状态机；`ChatGPTToolWorkHistoryStyle.containsPendingAuthorization` 让「等待授权」的工具组**默认展开**，不被折叠隐藏 |
| UI 测试使用双重启动守卫和隔离存储，无真实供应商/凭据/付费请求 | ✅ | 夹具要求 `--lumi-ui-testing` **且** `--lumi-ui-testing-message-list-chatgpt` 同时存在，缺全局开关即拒绝启用；UI 用例统一带 `--lumi-ui-testing-isolated-storage`；seed 阶段抑制自动回复（`setAutoReplySuppressed`），结束即解除 |
| 不新增原始错误/附件内容日志，不复制 OpenAI 专有资源 | ✅ | 沿用既有 `ErrorTransportDetailsResolver`，不新增日志；未引入任何 OpenAI 商标、图标、字体或专有资源 |

---

## 3. 实施过程中修掉的真实缺陷

| 缺陷 | 表现 | 修复 |
|---|---|---|
| 清空会话后旧行残留 | 存储被清空后界面继续显示已删除的消息 | `.cleared` 事件**直接清空窗口**；`refreshTail` 在存储为空时也清空窗口（`ChatGPTListViewModelTests` 覆盖） |
| `MessageListPaginationService` 配置在 Debug 下 trap、Release 下钳制 | 同一份配置在两种构建里行为不同 | 改为**一律钳制**，去掉 `assert`（`outOfRangeConfigurationIsClamped` 覆盖） |
| 渲染器 xcstrings 有 10 个 key 缺四语言翻译 | V5 可见文案在非中文环境下回退到 key 本身 | 补齐 en / zh-Hans / zh-Hant / zh-HK / zh-TW |
| 渲染器 xcstrings 存在空字符串 key | Xcode 的 symbol 生成无法从中派生符号名，构建失败 | 删除该无用条目 |
| 流式测试用固定 `sleep` 猜时序 | 慢机器上偶发失败 | 改为**轮询等待**条件成立 |

---

## 4. 未能验证的部分（如实记录）

| 项 | 原因 | 影响 |
|---|---|---|
| XCUITest 运行 | 本机 **XCTest automation mode 无法初始化**：`认证已取消。System authentication is running.`。同一时段仓库既有的 `LumiMessageListBriefUITests` 也在启动阶段以相同方式失败 | 16 个 UI 用例已**编写**但未执行；真实截图**未生成**（不伪造） |
| 无障碍树运行时验证 | `accessibility_observe` 返回「需要辅助功能权限」 | VoiceOver 路径未做运行时验证；标识符与 label 由单元测试守住 |
| 连续 streaming 的 CPU 采样 | 同上（需要启动 App 并观察） | 见 §2.2 对应条目 |
| 600 轮 / 1200 条消息的首屏实测耗时 | 同上 | 见 §2.2 对应条目 |

**替代证据**：新增 `ChatGPTMessageListEndToEndTests`，用**真实的**
`MessageStore` → `MessageManaging` → V5 ViewModel → `MessageRendererPlugin`
→ View 链路验证，4 个用例全绿。它直接守住「V5 不再是空 List」这条底线：
每条落库消息都必须到达渲染器，V5 槽位必须在 chatGPT 详细度下接管。

---

## 5. 回归与构建验证

| 检查 | 结果 |
|---|---|
| `swift test --package-path Packages/PluginMessageListChatGPT` | ✅ 122 tests / 12 suites |
| `swift test --package-path Packages/PluginMessageRenderer` | ✅ 277 tests / 27 suites |
| `swift test --package-path Packages/KitMarkdown` | ✅ 116 + 55 tests |
| `swift test --package-path Packages/ProviderMessageRendering` | ✅ 23 tests |
| `swift test --package-path Packages/FactoryLumi --filter "MessageListSlotArbitrationTests\|ChatGPTMessageListEndToEndTests"` | ✅ 11 tests |
| `swift test --package-path Packages/PluginConversationManager --filter ConversationManagerPreferenceTests` | ✅ 13 tests |
| `swift build -c release`（V5 / Renderer / ProviderMessageRendering / KitMarkdown 库） | ✅ 全部通过 |
| `xcodebuild build-for-testing -scheme Lumi` | ✅ **TEST BUILD SUCCEEDED**（含新 XCUITest 与端到端测试） |

### 已知与本特性无关的既有失败

| 失败 | 归属 |
|---|---|
| `FactoryLumiTests.stopWithdrawsContributionsAndSupportsRestart` | 与 V5 无关：临时从 `PluginFactory` 移除 V5 插件后**仍然失败**。属设置类插件的 shutdown 撤回行为，由 `a94e72fce`（Vendor 目录移除与远程 SPM 依赖恢复）引入 |
| `KitMarkdown` Release 下 `KitMarkdownTesting` target 报「unable to resolve Swift module dependency」 | 既有限制：辅助 target 在 Release 下引用库模块。**库本身** Release 构建通过，Debug 下全部测试通过 |
| `MailPluginRuntime.fallbackDataDirectory()` 在测试进程被调用 | 既有隔离守卫问题，与 V5 无关 |

---

## 6. 边界遵守

| 规范 | 遵守情况 |
|---|---|
| 内核与插件边界 | V5 包**不依赖**任何其它消息列表包；`Package.swift` 只声明实际使用的 Provider；渲染器仍在 `PluginMessageRenderer` 内，V5 列表包**不 import** 它 |
| 插件不得依赖插件 | ✅ `PluginMessageListChatGPT` 的依赖只有 `LumiKernel` / `LumiUI` / `LumiLogging` / `LumiLocalization` 与 6 个 `Provider*` 包 |
| 公开 renderer 签名不变 | ✅ `MessageRenderingProviding.MessageRendererItem.render` 签名**未改**；V5 只在 `render` 内部按 verbosity 分支 |
| 第三方 renderer 不受影响 | ✅ 不新增全局高优先级 renderer；`preferredRendererID` 仍优先 |
| 条件编译规范 | ✅ `MessageListChatGPTUITestingSupport.swift` 整体置于 `#if DEBUG` 内；插件入口的 seed 调用**与句柄赋值整段**在 `#if DEBUG` 内；`swift build -c release` 通过 |
| 文档管理规范 | ✅ 完成后未创建或更新任何 README（仅新增 `docs/plans/artifacts/` 下的评审索引，属方案 §5.4 指定的产物目录） |
| 最少功能原则 | ✅ 未实现方案 §0.2 明确排除的能力（编辑、分支、点赞、朗读、Canvas、LaTeX） |

---

## 7. 遗留事项

1. **UI 自动化恢复后补跑** 16 个 UI 用例，并按
   `docs/plans/artifacts/chatgpt-message-list-v5/README.md` 的矩阵生成真实截图。
2. **连续 streaming 的性能采样**（40+ 轮富文本 ≥ 5 秒）与
   **600 轮 / 1200 条消息的首屏耗时**需要在真实 App 上实测并记入 artifacts。
3. `FactoryLumiTests.stopWithdrawsContributionsAndSupportsRestart` 的既有失败
   建议单独排查（与 V5 无关，但会让 FactoryLumi 全量回归红）。
