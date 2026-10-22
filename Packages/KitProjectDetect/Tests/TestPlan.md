# TestPlan — KitProjectDetect

## 包概述

KitProjectDetect 通过项目根目录的清单文件推断项目类型，产出可直接展示的类型名与 SF Symbol 图标。
判定规则原先只存在于 `PluginProjectOverview`，且只输出字符串给 agent 工具；抽到本包后，
agent 工具与聊天空态共用同一份判定。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 8

核心组件（源码目录）:
- `Sources/KitProjectDetect/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ProjectTypeDescriptor`
- `ProjectTypeDetector`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ProjectTypeDetector**（8 条）：由 `detectsSwiftPackage`、`detectsXcodeProjectBySuffix`、`detectsNode`、`detectsMultipleTypesInRuleOrder`、`unknownRoot`、`unreadableDirectory`、`displayTextJoinsTypes`、`setOverloadMatchesArrayOverload` 等用例锁定。覆盖清单文件命中、后缀命中（`.xcodeproj` / `.csproj`）、多语言根目录按规则顺序输出、无法识别时降级为 unknown、目录不可读时降级、展示串拼接、数组与集合两个入口等价；改动判定规则表或优先级时必须优先跑该文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ProjectTypeDetector | a Swift package root is detected as Swift | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detectsSwiftPackage` |
| 2 | ProjectTypeDetector | an Xcode project is detected as Swift by suffix | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detectsXcodeProjectBySuffix` |
| 3 | ProjectTypeDetector | a Node root is detected as Node | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detectsNode` |
| 4 | ProjectTypeDetector | a polyglot root reports every matched type in rule order | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detectsMultipleTypesInRuleOrder` |
| 5 | ProjectTypeDetector | an unrecognized root is unknown rather than empty text | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownRoot` |
| 6 | ProjectTypeDetector | a directory that cannot be read degrades to unknown | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unreadableDirectory` |
| 7 | ProjectTypeDetector | the display text joins multiple types with a semicolon | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `displayTextJoinsTypes` |
| 8 | ProjectTypeDetector | the set based overload matches the array based one | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `setOverloadMatchesArrayOverload` |

> 说明：全部 **8 条场景**在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 6 / 6
- P2: 已覆盖 2 / 2
- **合计: 8 / 8**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（6 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 8 条用例位于 `Tests/KitProjectDetectTests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitProjectDetect
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
