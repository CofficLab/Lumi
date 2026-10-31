# TestPlan — KitTestSupport

## 包概述

KitTestSupport 的实现包，包含 5 个主要类型；当前测试覆盖 12 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 12

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `IsolatedDirectoryGuard`
- `TestProcessDetector`
- `IsolatedUserDefaults`
- `TemporaryDirectory`
- `TemporaryStorageProvider`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（9 条）：由 `createsDirectory`、`createsUniqueDirectories`、`removesDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TestProcessDetector**（3 条）：由 `detectsTestProcess`、`reportsWhichSignalMatched`、`doesNotDependOnXCTestCaseClass` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | 创建后目录存在 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createsDirectory` |
| 2 | 综合 | 每次创建得到互不相同的目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createsUniqueDirectories` |
| 3 | 综合 | 清理后目录消失，重复清理不抛错 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `removesDirectory` |
| 4 | 综合 | 写入值可读回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsBackWrittenValue` |
| 5 | 综合 | 不影响 UserDefaults.standard | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `doesNotTouchStandardDefaults` |
| 6 | 综合 | 不同实例之间互不可见 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `isolatesBetweenInstances` |
| 7 | 综合 | 数据根落在临时目录且保持版本命名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesVersionedRootInsideTemporaryDirectory` |
| 8 | 综合 | 插件目录与核心目录按需创建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `createsPluginAndCoreDirectories` |
| 9 | 综合 | 清理后整个临时根被删除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cleanupRemovesEverything` |
| 10 | TestProcessDetector | 在测试进程中判定为真 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detectsTestProcess` |
| 11 | TestProcessDetector | 记录判据命中的信号来源 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsWhichSignalMatched` |
| 12 | TestProcessDetector | 不依赖 XCTestCase 类是否存在 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotDependOnXCTestCaseClass` |

> 说明：全部 **12 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 10 / 10
- P2: 已覆盖 1 / 1
- **合计: 12 / 12**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（10 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 12 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitTestSupport
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
