# SPM 依赖锁文件同步规范

> 本规范定义了 Lumi 项目中 SPM 依赖锁文件（`Package.resolved`）的同步与校验要求，避免 Release CI 因 lock 不一致而失败。

---

## 核心原则

**主工程与 ACP 包的 lock 文件，共享依赖必须锁定到同一 revision。**

Lumi 有两份会被 CI 校验的 lock 文件：

| Lock 文件 | 路径 | 依赖数（参考） |
|---------|------|--------------|
| 主工程 | `Lumi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | ~80 |
| ACP 包 | `Packages/FactoryLumiACP/Package.resolved` | ~27 |

两者的**交集**（当前 27 个共享依赖）在 CI 中会被逐个比对 `location` + `revision`，只要有任一不一致即**直接失败**。

---

## 规则一：升级共享依赖时，两个 lock 必须一起更新

**任何**改动会落到共享依赖（如 `lumiui`、`lumiprovider`、`lumilogging`、`lumiplugincommand`、`lumisettings`）的版本/revision 的操作，都必须同步更新**两份** lock 文件。

常见触发场景：

- 在 Xcode 中升级主工程依赖（会更新主工程 lock，**不会**动 ACP lock）
- 执行 `swift package update <dep>` 但只在其中一个包目录下执行
- 新增一个 `Packages/*` 子包并让其依赖某个共享依赖
- 手动编辑 lock 文件

### 症状

Release workflow 在推送 `pre` / `main` 后约 1 分钟即失败，日志特征：

```
📋 Main lock: 80 dependencies
📋 ACP lock:  27 dependencies

  ❌ lumiui:
     main: 1.10.0 (64825782f709...)
     acp:  1.8.0 (188ec1668846...)

Summary: 26 matching, 1 mismatched, 53 unique to one lock

❌ Shared dependencies have different sources or revisions!
```

失败发生在 `Compute exact dependency cache key` 步骤，**早于任何实际编译**。因此这类失败与代码质量无关，纯属 lock 同步问题。

---

## 规则二：正确的升级流程

以升级 `lumiui` 为例，**必须两个目录都执行**：

```bash
# 1) 主工程（升级后会改写主工程 lock）
#    在 Xcode 中操作，或：
#    打开 Lumi.xcodeproj → 依赖列表 → 更新

# 2) ACP 包（改写 ACP lock）
cd Packages/FactoryLumiACP
swift package update lumiui

# 3) 本地校验（见规则三）
cd ../..
python3 .github/scripts/verify-package-locks.py \
  Lumi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
  Packages/FactoryLumiACP/Package.resolved
```

> **注意**：`swift package update` 只在该包自己的目录下生效，不会传播到主工程。反之在 Xcode 里升级也不会影响 ACP lock。**两个都要做。**

---

## 规则三：提交前本地校验（必须）

修改任何 lock 文件后，提交前**必须**跑一次校验：

```bash
python3 .github/scripts/verify-package-locks.py \
  Lumi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
  Packages/FactoryLumiACP/Package.resolved
```

通过标准：退出码 0，输出包含

```
Summary: 27 matching, 0 mismatched, ...
✅ All shared dependencies have matching revisions
```

**`mismatched` 必须为 0**。

### 关于 "unique to one lock"

输出中的 `53 dependencies only in main lock` 是**正常的**，不是错误。ACP 包只依赖主工程依赖的子集，唯一项偏多属预期。**只要 `mismatched` 为 0 即通过。**

---

## 规则四：只同步 lock pin，不擅自放宽约束

修复 lock 不一致时，**只允许修改 `Package.resolved` 中的 `revision` / `version`**，不得为了「让校验通过」而随意放宽 `Package.swift` 的版本约束。

- ✅ 正确：确认目标版本满足所有相关 `Package.swift` 的 `from:` 范围后，用 `swift package update` 正规同步 lock
- ❌ 错误：把 `from: "1.8.0"` 改成 `from: "1.0.0"` 或 `branch:` / `revision:` 绕过校验

判断目标版本是否合法：

```bash
grep -rn "LumiUI.git" Packages/*/Package.swift
```

若所有声明均为 `from: "1.8.0"` 或更低，则 `1.10.0` 合法，可直接同步。

---

## 规则五：CI 行为说明

- `Release` workflow 仅在 **push 到 `main` / `pre`** 时触发，`dev` 分支不受影响。
- 因此**只在 dev 上修好是不够的**，必须合并/推送到 `pre` 才会真正验证。
- 合并到 `pre` 后观察：若构建持续超过 ~2 分钟，说明已越过 lock 校验阶段（此前失败均在 1 分 23 秒内结束）。
- 校验逻辑本身有单测：`.github/scripts/test-verify-package-locks.py`，改动校验脚本时需同步维护。

---

## 检查清单

改动共享依赖版本时，确认：

- [ ] 主工程 lock 与 `Packages/FactoryLumiACP/Package.resolved` 均已更新
- [ ] 未改动 `Package.swift` 的版本约束（仅同步 lock）
- [ ] 提交前已运行 `verify-package-locks.py` 且 `mismatched == 0`
- [ ] 若修复目标是 `pre` / `main`，变更已推送到对应分支
- [ ] 未把 `unique to one lock` 误判为错误

---

## 相关规范

- [项目开发通用规则](./project-general-rules.md)
- [插件包目录结构规范](./plugin-package-structure.md)
- [Commit 规范](./commit-convention.md)
