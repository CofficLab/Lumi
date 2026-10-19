# TestPlan — ProviderLLMManager

## 包概述

ProviderLLMManager 的实现包，包含 5 个主要类型；当前测试覆盖 27 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 27

核心组件（源码目录）:
- `Errors/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DefaultLLMManager`
- `DefaultLLMManagerObserverHandle`
- `LLMManagerEvent`
- `LLMModelRoute`
- `LLMProviderManagerError`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **DefaultLLMProviderManagerProviding**（22 条）：由 `registerPreservesOrderAndReplaces`、`registerEmptyIDThrows`、`unregisterFallsBackSelection` 等用例锁定；改动该模块时优先跑对应测试文件。
- **DynamicModelList**（5 条）：由 `staticProviderUnchanged`、`remoteProviderDynamicModels`、`remoteProviderRefresh` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | DefaultLLMProviderManagerProviding | 注册保持插入顺序，重复注册覆盖并保持原位置 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `registerPreservesOrderAndReplaces` |
| 2 | DefaultLLMProviderManagerProviding | 注册空 id 抛 emptyProviderID | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `registerEmptyIDThrows` |
| 3 | DefaultLLMProviderManagerProviding | 注销后不可再查到，注销选中项回退到第一个供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unregisterFallsBackSelection` |
| 4 | DefaultLLMProviderManagerProviding | 注销不存在的 id 无副作用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unregisterUnknownIsNoop` |
| 5 | DefaultLLMProviderManagerProviding | 首次注册自动选中第一个供应商并落到默认模型 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `firstRegistrationSelectsDefault` |
| 6 | DefaultLLMProviderManagerProviding | select 切换供应商与模型，并校验模型归属 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectSwitchesProviderAndModel` |
| 7 | DefaultLLMProviderManagerProviding | 重复的供应商模型名通过全局模型 ID 唯一路由 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `globalModelIDDisambiguatesDuplicateProviderModelNames` |
| 8 | DefaultLLMProviderManagerProviding | 旧版全局供应商和模型设置等所属 Provider 注册后再迁移 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyGlobalSelectionWaitsForItsProvider` |
| 9 | DefaultLLMProviderManagerProviding | 选中模型不属于当前供应商时，发送回退默认模型 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `staleSelectedModelFallsBackToDefault` |
| 10 | DefaultLLMProviderManagerProviding | complete 路由到选中供应商并补充解析出的模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completeRoutesToSelectedProvider` |
| 11 | DefaultLLMProviderManagerProviding | 请求显式供应商时优先于全局选中供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completeRoutesToExplicitProvider` |
| 12 | DefaultLLMProviderManagerProviding | 请求自带模型时优先使用，不覆盖选中模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completePrefersRequestModel` |
| 13 | DefaultLLMProviderManagerProviding | 请求自带模型不属于选中供应商时回退解析模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestModelNotOwnedByProviderFallsBack` |
| 14 | DefaultLLMProviderManagerProviding | 无供应商时 complete 抛 noProviderConfigured | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completeWithoutProvidersThrows` |
| 15 | DefaultLLMProviderManagerProviding | complete 不改变持久化选中态（纯读取） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `completeDoesNotMutateSelection` |
| 16 | DefaultLLMProviderManagerProviding | 管理器作为 LLMProviding 的身份标识稳定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `managerIdentityIsStable` |
| 17 | DefaultLLMProviderManagerProviding | 注册/覆盖/注销投递 providersChanged 事件，首次注册与清空选中态均带 selectionChanged | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observersReceiveProviderChanges` |
| 18 | DefaultLLMProviderManagerProviding | 注销不存在的 id 不投递 providersChanged | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unregisterUnknownDoesNotNotify` |
| 19 | DefaultLLMProviderManagerProviding | 首次注册自动选中并投递 selectionChanged | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `firstRegistrationNotifiesSelection` |
| 20 | DefaultLLMProviderManagerProviding | select 切换供应商时投递 selectionChanged，重复选中不投递 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `selectNotifiesOnlyOnChange` |
| 21 | DefaultLLMProviderManagerProviding | 恢复持久化选中后，首次注册投递 .appRestore；后续注册回退为 .providerChanged | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `restoredSelectionBroadcastsAppRestoreOnce` |
| 22 | DefaultLLMProviderManagerProviding | 无持久化选中时不广播 .appRestore | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noRestoredSelectionDoesNotBroadcastAppRestore` |
| 23 | DynamicModelList | 静态供应商行为不变：models/modelRoute 仍走静态列表 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staticProviderUnchanged` |
| 24 | DynamicModelList | 远程 provider：availableModels 生效于 models/modelRoute/modelID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteProviderDynamicModels` |
| 25 | DynamicModelList | 远程 provider：刷新后 availableModels 变化立即反映到读取路径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteProviderRefresh` |
| 26 | DynamicModelList | notifyModelsRefreshed 广播 modelsRefreshed 事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelsRefreshedEvent` |
| 27 | DynamicModelList | 选中远程模型后刷新仍保持有效（模型仍在动态池） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionSurvivesRefresh` |

> 说明：全部 **27 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 20 / 20
- P2: 已覆盖 4 / 4
- **合计: 27 / 27**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（20 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 27 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderLLMManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
