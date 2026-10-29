# 条件编译（DEBUG / Release）规范

> 本规范定义了 Lumi 项目中条件编译（`#if DEBUG`）的使用约束，避免「本地 Debug 通过、Release 构建失败」的问题。

---

## 核心原则

**凡是只在 `#if DEBUG` 内定义的类型，其所有引用点必须整体处于同等守卫范围内——包括函数体，不能只包调用点。**

本地开发默认 Debug 配置，`DEBUG` 宏已定义，因此**几乎所有条件编译错误在本地都是隐形的**，只会在 CI 的 Release 构建中暴露。Release workflow 单次耗时 30–50 分钟，等 CI 才发现的代价很高。

---

## 规则一：引用面必须与定义面一致

若某类型/函数只在 `#if DEBUG` 内存在，则：

- ✅ 整个**函数体**（不只是调用语句）都应处于 `#if DEBUG` 内
- ❌ 仅在调用点写 `#if DEBUG`，函数体裸露

```swift
// ❌ 错误：Release 下函数体仍在编译，报 cannot find 'XxxSupport' in scope
#if DEBUG
    if let manager {
        seedFixture(manager: manager)   // 调用点被包裹
    }
#endif

private func seedFixture(...) {
    guard XxxSupport.isEnabled else { return }   // ← 函数体裸露，Release 编译失败
}

// ✅ 正确：定义与引用面完全对齐
#if DEBUG
private func seedFixture(...) {
    guard XxxSupport.isEnabled else { return }
    // ...
}
#endif
```

**判据**：把该文件的所有 `#if DEBUG` 块去掉后，剩余代码能否独立编译？能则安全。

### 属性例外

仅在 DEBUG 函数内被赋值的**存储属性**不必包裹 —— 属性声明本身在 Release 下合法（只是恒为 `nil`），不会触发编译错误。Swift 不对「声明后仅在条件编译分支内使用」报错。

---

## 规则二：CI 夹具的归属约定

UI 测试夹具（`*UITestingSupport.swift`）的既有范式是**整个文件**置于 `#if DEBUG` 内：

```swift
#if DEBUG
import Foundation
@MainActor
public enum XxxUITestingSupport { ... }
#endif
```

引用它的插件代码必须遵守规则一对齐守卫范围。参考实现：

| 夹具 | 引用方 |
|------|--------|
| `PluginAgentLoop/ErrorRetryUITestingSupport.swift` | `PluginAgentLoop.swift` 的 `seedErrorRetryUITestingFixtureIfNeeded` |
| `PluginMessageListBrief/MessageListBriefUITestingSupport.swift` | 同插件调用点 |

---

## 规则三：提交前必须用 Release 配置验证

改动涉及条件编译、启动参数、UI 测试夹具或 `*Support` 类型时，**提交前**至少对一个受影响的包跑一次 Release 编译：

```bash
cd Packages/<PackageName>
swift build -c release
```

Debug 与 Release 都要通过：

```bash
swift build -c debug && swift build -c release
```

包少时可直接全量验证：

```bash
cd Packages && for p in PluginAgentLoop PluginMessageListBrief; do (cd $p && swift build -c release) || break; done
```

> 只改动单个包时优先只编译该包；全仓 Release 编译耗时长，不必每次执行。

---

## 规则四：识别「本地隐形」的信号

出现以下情况，应立刻怀疑条件编译不一致，并在提交前跑 `-c release`：

- 新增/修改了 `*UITestingSupport.swift`、`*TestFixture*.swift` 等夹具文件
- 在 `onBoot` / `onReady` / `onEnable` 等生命周期钩子里新增了 `#if DEBUG` 分支
- 任何 `ProcessInfo.processInfo.arguments.contains(launchArgument)` 判定的消费方
- CI 报 `cannot find 'Xxx' in scope`，而本地 Debug 一切正常 —— **这是本规范的典型症状**

---

## 真实事故记录

**2026-10-15**：`PluginAgentLoop.swift` 的 `seedErrorRetryUITestingFixtureIfNeeded` 只在调用点加了 `#if DEBUG`，函数体仍引用 `ErrorRetryUITestingSupport`。本地 Debug 正常，Release workflow 在 Archive 阶段（arm64 / x86_64 各 5 处）报：

```
error: cannot find 'ErrorRetryUITestingSupport' in scope
```

修复：函数体整体纳入 `#if DEBUG`，并补 `- Important:` 注释说明约束，避免后续重构再次拆散守卫。

---

## 检查清单

涉及条件编译或 UI 测试夹具时，确认：

- [ ] 只在 `#if DEBUG` 定义的类型，其所有函数体引用点均在 `#if DEBUG` 内
- [ ] 去掉所有 `#if DEBUG` 后剩余代码可独立编译
- [ ] 已执行 `swift build -c release` 并通过
- [ ] 已执行 `swift build -c debug` 并通过（确认未误伤 Debug 路径）
- [ ] 新增夹具消费方时补了 `- Important:` 注释说明守卫约束

---

## 相关规范

- [项目开发通用规则](./project-general-rules.md)
- [SPM 依赖锁文件同步规范](./spm-package-lock-sync.md)
- [插件包目录结构规范](./plugin-package-structure.md)
