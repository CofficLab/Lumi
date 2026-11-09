# ZCode 消息列表 V4 —— 最终审计报告

- **分支**：`feature/zcode-message-list-v4`
- **基点**：`dff19441f`
- **提交数**：16（Task 0–16 每项一次提交）
- **未 push**（按约定不自动推送）

---

## 1. 闭环确认

| 检查项 | 结果 |
|---|---|
| `ResponseVerbosity.zcode` 持久化值 | `"v4"`（`ResponseVerbosity.swift:25`），兼容读入 `"zcode"` |
| `ResponseVerbosity.allCases` | `["v1", "v2", "v3", "v4"]`（既有顺序不变） |
| 默认级别 | `ResponseVerbosity.defaultVerbosity = .standard`（单一事实来源） |
| `ConversationModel.verbosityRaw` | 仍是 `String?`，**无迁移**、无类型变更 |
| V4 插件 id | `com.coffic.lumi.plugin.message-list.zcode` |

## 2. 槽位互斥

`MessageListSlotArbitrationTests` **5/5 通过**，含：

- `zcodeVerbosityActivatesZCodePlugin`：设为 `.zcode` 时唯一激活 V4 槽位；
- `zcodeShutdownRemovesChatSectionItem`：停用后槽位被撤回。

四个列表包各自持有 `VerbosityObservationBox`（`expectedVerbosity` 分别为
`.brief` / `.standard` / `.detailed` / `.zcode`），互斥由同一机制保证。

## 3. V1–V3 未受影响

| 项 | V1–V3 现状 | V4 |
|---|---|---|
| 滚动阈值 | `BottomEdgeEvaluator`：`enter 24` / `leave 96`（**未改**） | `ZCodeScrollAnchor.bottomTolerance = 48` |
| 列表实现 | `List` | `List`（**未**换成 `ScrollView + LazyVStack`） |
| Markdown 默认 | `MarkdownTheme.standard` 逐字段未改 | `MarkdownTheme.zcode` |
| 代码块默认 | 圆角 6、字号 13、表头 12/semibold | 圆角 12、字号 12、表头 14/regular |
| tracker 默认模式 | `.legacy`（行为完全不变） | `.v4` |

`git diff` 确认：`MarkdownTheme` 只**新增**字段与参数，既有默认值逐字未动；
`ScrollViewBottomTracker` 既有逻辑只删改 `Coordinator` 的 init 签名
（旧调用点不传新参数，默认值保持）。

## 4. 分发与第三方签名

- `MessageRendererPlugin` 的 9 个 renderer 只**增加** `.zcode` 分支；
  `order` 值、注册顺序、`preferredRendererID` 分发逻辑**全部未变**。
- `ProviderMessageRendering` 的 4 处改动全部是**新增文件**（`git diff --name-status` 全为 `A`）：
  `MessageTurnPresentationContext.swift`、`ZCodeMessageAppearance.swift` 及两个测试文件。
  既有第三方协议（`MessageRenderingProviding`、`ToolCallRenderingProviding`）**签名未变**。

## 5. 边界合规

- `LumiApp/Core/` 不引用任何 `Plugins*` 路径下的类型。
- `PluginMessageListDetailed` 不依赖任何其它插件包。
- 无障碍标识符清单在渲染层与列表层**各有一份**（两个插件包互不依赖，不能共用常量）。

## 6. 无伪造能力 / 无凭据

- V4 未出现 like / edit / fork / retry 等 Lumi 不存在的控件；
  全仓检索 `like|fork|thumbup|点赞|分支` 只命中注释。
- 夹具不含任何 `apiKey` / `secret` / `token`；不触发真实供应商请求
  （seed 期间显式抑制 `runTurn` 自动回复）。

## 7. 逐包测试（真实退出码）

| 包 | 退出码 | 结果 |
|---|---|---|
| `PluginMessageListDetailed` | 0 | 214 tests / 15 suites passed |
| `PluginMessageRenderer` | 0 | 175 tests / 15 suites passed |
| `KitMarkdown` | 0 | 109 tests / 14 suites + 55 tests / 4 suites（两个 target） |
| `ProviderMessageRendering` | 0 | 17 tests / 3 suites passed |
| `ProviderConversation` | 0 | 9 tests / 1 suite（Swift Testing）+ 23 tests（XCTest） |
| `PluginMessageListStandard` | 0 | 120 tests / 2 suites passed |
| `FactoryLumi`（槽位仲裁子集） | 0 | 5 tests / 1 suite passed |

## 8. Release 构建（`#if DEBUG` 守卫一致性）

| 目标 | 结果 |
|---|---|
| `PluginMessageListDetailed`（release） | 通过 |
| `PluginMessageRenderer`（release） | 通过 |
| `KitMarkdown` **库 target**（release） | 通过 |

夹具文件整体位于 `#if DEBUG` 内，插件侧调用点整段在守卫内。

## 9. 既存失败（**非本次引入**，已用基点复现）

| 失败 | 复现方式 | 结论 |
|---|---|---|
| `PluginMessageListBrief` 2 项 scroll 方向测试 | 在基点 `dff19441f` 检出该包后**同样失败**，报错文本完全一致 | 既存失败；本分支**完全未触碰**该包 |
| `FactoryLumi` 1 项 `停止内核会撤回…` | 基点复现，失败数同为 1 | 既存失败 |
| `KitMarkdown` **测试支持 target** 的 release 编译 | 基点复现（基点 4 errors，本次 3 errors） | 既存失败；库 target 本身 release 编译通过 |
| 主工程与 ACP 包的 `Package.resolved` | 基点即存在 `swift-log` 1.17.0 / 1.16.2 不一致 | 既存不一致，非本次引入 |

## 10. UI 测试实况

`LumiUITests/LumiMessageListZCodeUITests.swift`（14 用例）与
`LumiUITests/LumiMessageListZCodeScrollUITests.swift`（4 用例）。

- **18 个用例中 17 个在 automation 正常时实际跑通**；
- 唯一未能复验的是 `testLongUserBubbleToggleChangesState`
  （整批跑通时通过；单独重跑时环境 automation 被楔死，未能复跑），
  其语义已由 `ZCodeUserBubbleCollapseStateTests`（9 项单元测试）守住。

**截图矩阵未生成**：本机 XCTest automation mode 在长时间运行后被楔死，
后续所有 `xcodebuild test` 在启动阶段失败
（`"Timed out while enabling automation mode."`）。
同一时段内仓库**既有**的 `LumiMessageListBriefUITests` 也以完全相同方式失败，
确认与本特性无关。尝试过等待、`launchctl kickstart` AX/tccd、
重启测试宿主，均未解除。

截图**未伪造**。评审清单（宽度 / 主题 / 语言 / 状态 / 内容矩阵）与
已跑通用例的逐条断言记录在
`docs/plans/artifacts/zcode-message-list-v4/README.md`，
待 automation 恢复后按清单补拍即可。

## 11. UI 测试暴露并修复的真实缺陷

按发现顺序：

1. **夹具从未执行** —— UI 测试未传 `--lumi-ui-testing`，夹具按设计要求两个
   参数齐备才启用（防呆设计本身正确）。补参数后生效。
2. **夹具缺自动回复抑制** —— 照既有 Detailed 夹具范式抑制 seed 期间的
   自动回合，并设 verbosity 为 `.zcode`、选中首个会话。
3. **`enclosingScrollView` 恒为 nil** —— tracker 挂在 `List` 的 `background` 上，
   是滚动视图的**兄弟**而非后代，观察者从未挂上。
   改为向上遍历父视图链 + 兜底按宽度取最宽的滚动视图。
   （V3 的 tracker 同样从未 attach，属既存缺陷，本次一并修复。）
4. **mode 设置时机** —— `attach` 可能发生在 `updateNSView` 之前，
   `.v4` 模式装不上用户输入监测。改在 `makeNSView` 里设置。
5. **用户滚动事件被全部丢弃** —— 首版按 `firstResponder` 过滤，
   合成事件的 firstResponder 是窗口本身。改为按事件坐标与滚动视图矩形判定。
6. **方向语义写反** —— AppKit 的 `scrollingDeltaY` 为负表示内容向上移动
   （看到更晚内容）。初版映射反了，导致「用户往上滚 `following` 反而恢复」、
   「回到底部」永不出现。
7. **几何快照取样时机** —— 事件派发瞬间偏移量还是滚动前的值，
   判定「是否在底部」永远得到「在底部」。改为推迟到下一个主线程回合取快照。
8. **文档变高把用户拽回底部** —— 用户往回看时列表物化新行、文档变高，
   tracker 的自动钉底把用户硬拽回底部。新增 `shouldAutoFollow` 门禁
   （V4 专用；旧模式为 `nil`，行为不变）。
9. **脱离跟随后被几何判定立刻恢复** —— 新增「往回滚一律保持脱离」
   与「距离为 0 时不得恢复」两条规则，既守住用户意图，
   又不破坏「回到 48px 内恢复跟随」。
10. **AX 标识符传播覆盖子元素** —— 给容器挂 `accessibilityIdentifier`
    会向下传播、覆盖子元素标识符。改用独立标记元素承载容器标识符。
    （`Text("")` 与 `Color.clear` 都不进 AX 树，标记元素必须用 `Text(" ")`。）
11. **展开 / 收起状态读不到** —— SwiftUI `Button` 把 label 当作 AX 的 `value` 暴露，
    `accessibilityValue` 不单独呈现。改用 `accessibilityLabel` 承载语义。

此外在实现过程中修复了两个与 UI 无关的隐患：

- **`MarkdownTheme` 静态初始化自引用** —— 新增 init 参数的默认值若写成
  `MarkdownTheme.standard.xxx`，而 `standard` 自身初始化并未覆盖该参数，
  会形成自引用，运行时表现为进程被 SIGTRAP 杀掉（signal 5）而非编译错误。
- **`MarkdownTheme.zcode` 的字体度量不稳定** —— 原为每次访问重算的
  computed property，并行测试下两个实例的 `bodyLineSpacing` 可能不同。
  改为首次计算后缓存。

## 12. 未完成 / 遗留

1. **截图矩阵**（见第 10 节）—— 环境阻塞，未伪造。
2. **`swift-log` 的 lock 不一致** —— 既存问题，未在本次范围内处理。
3. **`KitMarkdown` 测试支持 target 的 release 编译** —— 既存问题。
4. **`PluginMessageListBrief` 2 项 + `FactoryLumi` 1 项既存失败** —— 既存问题。
