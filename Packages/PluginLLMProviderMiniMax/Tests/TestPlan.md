# TestPlan — PluginLLMProviderMiniMax

## 包概述

PluginLLMProviderMiniMax 的实现包，包含 5 个主要类型；当前测试覆盖 21 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 21

核心组件（源码目录）:
- `LLMProviders/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MiniMaxLocalStore`
- `MiniMaxProviderPlugin`
- `MiniMaxUITestingSupport`
- `MiniMaxVendorModels`
- `MiniMaxRemoteModelListLoader`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **MiniMaxLocalStore**（9 条）：由 `writesSnapshotToPluginDirectory`、`configureUsesPluginDataDirectory`、`storeEmptyIgnored` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MiniMaxProviderPlugin**（10 条）：由 `pluginIdentityAndMetadata`、`pluginRegistersMiniMaxProvider`、`miniMaxModelCatalog` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MiniMaxRefreshReproduction**（2 条）：由 `refreshShouldExpandModelPoolFrom6To9`、`remoteOnlyModelsAreAppended` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | MiniMaxLocalStore | 写入后落盘到指定目录的 models.json | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `writesSnapshotToPluginDirectory` |
| 2 | MiniMaxLocalStore | configure 绑定到内核分配的插件目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `configureUsesPluginDataDirectory` |
| 3 | MiniMaxLocalStore | store 空列表被忽略，不覆盖已有缓存 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `storeEmptyIgnored` |
| 4 | MiniMaxLocalStore | 过期快照仍可读，仅标记 isStale | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staleSnapshotStillReadable` |
| 5 | MiniMaxLocalStore | 磁盘内容损坏时返回 nil 并回退静态清单 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `corruptedDiskFallsBack` |
| 6 | MiniMaxLocalStore | clear 清空内存与磁盘文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearRemovesSnapshot` |
| 7 | MiniMaxLocalStore | 未绑定目录时降级为纯内存，不产生任何文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `inMemoryFallbackWritesNothing` |
| 8 | MiniMaxLocalStore | provider 在 store 未注入时仍回退静态清单 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerFallsBackToStaticCatalogWithoutStore` |
| 9 | MiniMaxLocalStore | provider 从注入的 store 读到缓存模型并合入模型池 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerReadsInjectedStore` |
| 10 | MiniMaxProviderPlugin | 插件身份与元数据稳定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginIdentityAndMetadata` |
| 11 | MiniMaxProviderPlugin | onBoot 注册唯一 MiniMax OpenAI 协议供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersMiniMaxProvider` |
| 12 | MiniMaxProviderPlugin | MiniMax 共享模型清单完整有序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `miniMaxModelCatalog` |
| 13 | MiniMaxProviderPlugin | MiniMax 指向 minimaxi.com 端点 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `miniMaxEndpointConfiguration` |
| 14 | MiniMaxProviderPlugin | MiniMax 支持远程模型源 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `miniMaxUsesRemoteModelSource` |
| 15 | MiniMaxProviderPlugin | 远程模型列表解析只提取模型 id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteModelListParsing` |
| 16 | MiniMaxProviderPlugin | 远程列表解析失败时抛错而非返回空列表 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `remoteModelListParsingRejectsInvalidPayload` |
| 17 | MiniMaxProviderPlugin | 合并策略保留静态元数据并追加远程新增模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteMergeKeepsStaticMetadata` |
| 18 | MiniMaxProviderPlugin | onBoot 在缺少 LLM 管理器时不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootWithoutManagerDoesNotThrow` |
| 19 | MiniMaxProviderPlugin | onShutdown 不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onShutdownDoesNotThrow` |
| 20 | MiniMaxRefreshReproduction | 刷新后模型池应从 6 变为 9（manager 即 UI 读取路径） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshShouldExpandModelPoolFrom6To9` |
| 21 | MiniMaxRefreshReproduction | 远程新增模型应追加到静态清单之后 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteOnlyModelsAreAppended` |

> 说明：全部 **21 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 17 / 17
- P2: 已覆盖 2 / 2
- **合计: 21 / 21**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（17 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 21 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginLLMProviderMiniMax
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
