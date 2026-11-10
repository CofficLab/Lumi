# TestPlan — KitOpenIn

## 包概述

KitOpenIn 的实现包，包含 3 个主要类型；当前测试覆盖 8 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 8

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `OpenInAboutView`
- `OpenInManualView`
- `OpenInTool`
- `OpenInFailureReporting`
- `OpenInFailureToastReporter`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **OpenInTool**（6 条）：由 `presetConfigurationsKeepStableToolNamesAndFallbacks`、`toolMetadataDeclaresOptionalPathAndLowRisk`、`explicitPathOverridesProjectAndEmptyPathFallsBack`、`conversationProjectOverridesCurrentProject` 等用例锁定；工具必须按调用所属会话的项目解析路径，显式 path 优先。
- **OpenInFailureReporting**（2 条）：失败必须转成用户可见的错误 Toast；未注册 Toast 能力时安静降级。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | OpenInTool | presetConfigurationsKeepStableToolNamesAndFallbacks | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `presetConfigurationsKeepStableToolNamesAndFallbacks` |
| 2 | OpenInTool | toolMetadataDeclaresOptionalPathAndLowRisk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolMetadataDeclaresOptionalPathAndLowRisk` |
| 3 | OpenInTool | explicitPathOverridesProjectAndEmptyPathFallsBack | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `explicitPathOverridesProjectAndEmptyPathFallsBack` |
| 4 | OpenInTool | executionThrowsWhenNoPathOrProjectExists | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executionThrowsWhenNoPathOrProjectExists` |
| 5 | OpenInTool | 会话绑定项目优先于当前项目，显式 path 仍最优先 | 显式/会话/当前三条路径同时存在 | 调用 `resolvedTargetPath` | 依次取显式、会话、当前 | P1 | ✅ 已覆盖 | `conversationProjectOverridesCurrentProject` |
| 6 | OpenInTool | 会话绑定项目被真正传入路径解析 | 当前项目为 `/workspace/Current`，会话绑定 `/workspace/Conversation` | 调用 `resolvedPath(_:conversationProjectPath:)` | 返回会话项目路径 | P1 | ✅ 已覆盖 | `conversationProjectIsPlumbedIntoResolution` |
| 7 | OpenInFailureReporting | 失败会转换成错误 Toast，并保留标题与原因（**回归 #549**） | 注入记录型 Toast 实现 | `reportOpenFailure` | 收到一条 `.error` Toast，标题/详情一致 | P1 | ✅ 已覆盖 | `reportsFailureAsErrorToast` |
| 8 | OpenInFailureReporting | 没有注册 Toast 能力时安静降级 | `toast == nil` | `reportOpenFailure` | 不崩溃、无副作用 | P2 | ✅ 已覆盖 | `toleratesMissingToastProvider` |

> 说明：全部 **8 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 5 / 5
- P2: 已覆盖 3 / 3
- **合计: 8 / 8**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（5 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 8 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitOpenIn
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
