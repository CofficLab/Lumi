# TestPlan — PluginConversationTitle

## 包概述

PluginConversationTitle 的实现包，覆盖「自动生成标题」与「Chat Header 展示标题」两条链路；当前测试覆盖 47 条用例。

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 47

测试文件:
- `AutoTitleRuleTests.swift` — 纯函数契约（标题规则、清洗、注入防护）
- `TitleServiceTests.swift` — 自动标题端到端链路（依赖 TestDoubles）
- `TitleUpdateToolTests.swift` — Agent 工具 `update_conversation_title`
- `HeaderTitleObserverTests.swift` — 事件 → ViewModel 展示链路
- `PluginConversationTitleTests.swift` — 早期基础用例
- `TestDoubles.swift` — in-memory Provider 替身（非用例）

核心组件（源码目录）:
- `Observers/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConversationTitlePlugin`
- `ConversationTitleHeaderObserver`
- `TitleService`
- `TitleUpdateTool`
- `ConversationTitleViewModel`
- `HeaderView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **标题规则**（`AutoTitleRuleTests`，17 条）：`shouldApplyGeneratedTitle` 决定何时允许覆盖标题；`fencedUserMessage` 负责阻断标签注入；`normalizeTitle` / `placeholderTitle` 负责清洗与 40 字截断。
- **自动标题链路**（`TitleServiceTests`，11 条）：消息插入事件 → 首条用户消息判定 → LLM 生成 → 写库，含三条「不写库」路径与 `stop` 生命周期。
- **标题更新工具**（`TitleUpdateToolTests`，8 条）：`update_conversation_title` 的成功与三条 ❌ 分支；返回值会直接展示给 LLM，措辞改动需同步断言。
- **Header 展示链路**（`HeaderTitleObserverTests`，7 条）：`ConversationEvent` 白名单驱动 ViewModel 刷新；新增事件类型若忘记加入白名单，由 `allEventsRefreshTitle` 拦截。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 标题规则 | shouldApplyGeneratedTitle：无标题时放行 | — | 执行该用例 | nil/空串/纯空白标题均放行 | P2 | ✅ 已覆盖 | `appliesWhenNoTitle` |
| 2 | 标题规则 | shouldApplyGeneratedTitle：保护自定义标题 | — | 执行该用例 | 自定义标题不被覆盖 | P0 | ✅ 已覆盖 | `protectsCustomTitle` |
| 3 | 标题规则 | shouldApplyGeneratedTitle：生成结果与当前标题相同则跳过 | — | 执行该用例 | 相同则跳过，先规范化空白 | P2 | ✅ 已覆盖 | `skipsWhenSameAsCurrent` |
| 4 | 标题规则 | shouldApplyGeneratedTitle：占位标题可被替换 | — | 执行该用例 | 占位标题允许被更好标题替换 | P2 | ✅ 已覆盖 | `replacesPlaceholderTitle` |
| 5 | 标题规则 | shouldApplyGeneratedTitle：短消息的占位标题等于原文 | — | 执行该用例 | 短消息占位标题即原文 | P2 | ✅ 已覆盖 | `shortMessagePlaceholderEqualsSource` |
| 6 | 标题规则 | shouldApplyGeneratedTitle：生成前预检查不比较生成值 | — | 执行该用例 | generatedTitle 为 nil 时不短路 | P2 | ✅ 已覆盖 | `preflightCheckIgnoresGeneratedTitle` |
| 7 | 标题规则 | fencedUserMessage：转义闭合标签，阻断标签注入 | — | 执行该用例 | 只保留一个真实闭合标签 | P0 | ✅ 已覆盖 | `fencesClosingTag` |
| 8 | 标题规则 | fencedUserMessage：普通消息原样包裹 | — | 执行该用例 | 正常消息不��改写 | P2 | ✅ 已覆盖 | `fencesPlainMessage` |
| 9 | 标题规则 | normalizeTitle：空串与纯空白返回空串 | — | 执行该用例 | 返回空串 | P2 | ✅ 已覆盖 | `normalizeEmpty` |
| 10 | 标题规则 | normalizeTitle：跳过前置空行 | — | 执行该用例 | 取第一条非空行 | P2 | ✅ 已覆盖 | `normalizeSkipsLeadingBlankLines` |
| 11 | 标题规则 | normalizeTitle：剥离成对引号与书名号 | — | 执行该用例 | 中英文引号均被剥离 | P2 | ✅ 已覆盖 | `normalizeStripsWrappers` |
| 12 | 标题规则 | normalizeTitle：折叠内部空白 | — | 执行该用例 | 多余空白折叠为单空格 | P2 | ✅ 已覆盖 | `normalizeCollapsesWhitespace` |
| 13 | 标题规则 | normalizeTitle：40 字符边界不截断 | — | 执行该用例 | 恰好 40 字符不截断 | P0 | ✅ 已覆盖 | `normalizeLengthBoundary` |
| 14 | 标题规则 | normalizeTitle：截断后清理尾部空白 | — | 执行该用例 | 截断点落在空白时清尾 | P2 | ✅ 已覆盖 | `normalizeTrimsAfterTruncation` |
| 15 | 标题规则 | placeholderTitle：折叠换行与连续空白 | — | 执行该用例 | 换行折叠为空格 | P2 | ✅ 已覆盖 | `placeholderCollapsesWhitespace` |
| 16 | 标题规则 | placeholderTitle：恰好 40 字符不追加省略号 | — | 执行该用例 | 边界不追加省略号 | P0 | ✅ 已覆盖 | `placeholderLengthBoundary` |
| 17 | 标题规则 | placeholderTitle：纯空白折叠为空串 | — | 执行该用例 | 返回空串 | P2 | ✅ 已覆盖 | `placeholderEmpty` |
| 18 | 标题更新工具 | 更新选中会话标题返回成功文案 | — | 执行该用例 | 返回 ✅ 且含新标题与会话 ID | P2 | ✅ 已覆盖 | `updatesSelectedTitle` |
| 19 | 标题更新工具 | 写入前裁剪标题首尾空白 | — | 执行该用例 | 落库内容无首尾空白 | P2 | ✅ 已覆盖 | `trimsWhitespace` |
| 20 | 标题更新工具 | Provider 缺失时返回服务不可用 | — | 执行该用例 | 返回服务不可用文案 | P0 | ✅ 已覆盖 | `reportsMissingProvider` |
| 21 | 标题更新工具 | 未选中会话时返回未找到 | — | 执行该用例 | 返回未找到文案 | P0 | ✅ 已覆盖 | `reportsNoSelection` |
| 22 | 标题更新工具 | 写库失败时返回失败文案而不抛出 | — | 执行该用例 | 返回失败文案且不抛错 | P0 | ✅ 已覆盖 | `reportsPersistenceFailure` |
| 23 | 标题更新工具 | 非法 title 参数抛 ToolExecutionError | — | 执行该用例 | 缺参/空串/空白/非字符串均抛错 | P0 | ✅ 已覆盖 | `rejectsInvalidArguments` |
| 24 | 标题更新工具 | 工具描述与输入 schema | — | 执行该用例 | 名称、描述、schema、风险等级符合约定 | P2 | ✅ 已覆盖 | `metadata` |
| 25 | 标题更新工具 | displayDescription 回退与正常展示 | — | 执行该用例 | 空参数回退通用文案 | P2 | ✅ 已覆盖 | `displayDescription` |
| 26 | 自动标题链路 | 首条用户消息生成标题并写库 | — | 执行该用例 | 触发一次 LLM 并写入清洗后标题 | P2 | ✅ 已覆盖 | `generatesTitleForFirstUserMessage` |
| 27 | 自动标题链路 | 生成标题的请求包含 system 指令与包裹后的用户消息 | — | 执行该用例 | 两条消息结构正确 | P0 | ✅ 已覆盖 | `composesPromptWithFence` |
| 28 | 自动标题链路 | 非首条用户消息不触发标题生成 | — | 执行该用例 | 无 LLM 请求、无写库 | P0 | ✅ 已覆盖 | `ignoresNonFirstUserMessage` |
| 29 | 自动标题链路 | 非用户角色的消息被忽略 | — | 执行该用例 | assistant 消息不触发生成 | P2 | ✅ 已覆盖 | `ignoresNonUserRole` |
| 30 | 自动标题链路 | 已有自定义标题时不覆盖 | — | 执行该用例 | 不请求 LLM、不写库 | P0 | ✅ 已覆盖 | `doesNotOverwriteCustomTitle` |
| 31 | 自动标题链路 | LLM 失败时不写库 | — | 执行该用例 | 标题保持 nil | P0 | ✅ 已覆盖 | `doesNotPersistWhenLLMFails` |
| 32 | 自动标题链路 | LLM 返回空标题时不写库 | — | 执行该用例 | 无写库请求 | P0 | ✅ 已覆盖 | `doesNotPersistEmptyTitle` |
| 33 | 自动标题链路 | 写库失败时不抛出异常 | — | 执行该用例 | 不崩溃且内存态不被污染 | P0 | ✅ 已覆盖 | `toleratesPersistenceFailure` |
| 34 | 自动标题链路 | 空内容用户消息被忽略 | — | 执行该用例 | 纯空白消息不触发生成 | P2 | ✅ 已覆盖 | `ignoresBlankMessage` |
| 35 | 自动标题链路 | stop 后不再响应消息插入 | — | 执行该用例 | 订阅已解除 | P0 | ✅ 已覆盖 | `stopsObserving` |
| 36 | 自动标题链路 | 重复 stop 幂等 | — | 执行该用例 | cancel 仅计一次 | P2 | ✅ 已覆盖 | `stopIsIdempotent` |
| 37 | Header 展示链路 | ViewModel 相同标题重复写入短路 | — | 执行该用例 | 不触发重复发布 | P2 | ✅ 已覆盖 | `viewModelSkipsDuplicateTitle` |
| 38 | Header 展示链路 | ViewModel 初始标题为空串 | — | 执行该用例 | 初值为空串 | P2 | ✅ 已覆盖 | `viewModelStartsEmpty` |
| 39 | Header 展示链路 | Observer 初始化时同步当前标题 | — | 执行该用例 | 构造即完成首次同步 | P2 | ✅ 已覆盖 | `syncsInitialTitle` |
| 40 | Header 展示链路 | 全部会话事件都触发标题刷新 | — | 执行该用例 | 11 种事件均刷新标题 | P0 | ✅ 已覆盖 | `allEventsRefreshTitle` |
| 41 | Header 展示链路 | 取消选择后标题回落为空串 | — | 执行该用例 | 标题回落为空 | P2 | ✅ 已覆盖 | `clearsTitleOnDeselection` |
| 42 | Header 展示链路 | cancel 后不再响应会话事件 | — | 执行该用例 | 订阅已解除 | P0 | ✅ 已覆盖 | `stopsAfterCancel` |
| 43 | Header 展示链路 | 重复 cancel 幂等 | — | 执行该用例 | cancel 仅计一次 | P2 | ✅ 已覆盖 | `cancelIsIdempotent` |
| 44 | 标题规则 | 标题生成：normalizeTitle 清理引号与换行 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizeTitle` |
| 45 | 标题规则 | 占位标题：长消息截断到 40 字符 | — | 执行该用例 | 截断并追加省略号 | P0 | ✅ 已覆盖 | `placeholderTitle` |
| 46 | 标题更新工具 | 标题更新工具：更新选中会话标题 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `updateToolUpdatesTitle` |
| 47 | 标题更新工具 | 标题更新工具：缺参数抛错 | — | 执行该用例 | 抛 ToolExecutionError | P0 | ✅ 已覆盖 | `updateToolMissingArgument` |

> 说明：全部 **47 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 19 / 19
- P1: 已覆盖 0 / 0
- P2: 已覆盖 28 / 28
- **合计: 47 / 47**（仅表示清单场景，非源码覆盖率）

源码行覆盖率（`swift test --enable-code-coverage` + `llvm-cov` 实测，71.28%）：

| 文件 | 行覆盖率 | 说明 |
|------|---------|------|
| `Tools/TitleUpdateTool.swift` | 100.00% | 全部分支已覆盖 |
| `ViewModels/ConversationTitleViewModel.swift` | 100.00% | 全部分支已覆盖 |
| `Observers/ConversationTitleHeaderObserver.swift` | 100.00% | 全部分支已覆盖 |
| `Observers/TitleService.swift` | 92.78% | 未覆盖为 headless 禁用分支（依赖进程环境变量） |
| `ConversationTitlePlugin.swift` | 0.00% | `onBoot` / `onShutdown` 需完整 Kernel 容器，成本高于收益，暂不覆盖 |
| `Views/HeaderView.swift` | 0.00% | 纯 SwiftUI 渲染，无业务分支 |

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试、阻断、不覆盖、幂等等失效类信号的用例（19 条）
- **P1**: 其余功能性用例（0 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（28 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 47 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationTitle
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
