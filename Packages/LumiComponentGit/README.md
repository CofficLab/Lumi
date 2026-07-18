# LumiComponentGit

LumiCore 的 Git 功能组件包。

## ⚠️ 依赖约束

**此包只能被 LumiCoreKit 依赖，不应被其他任何包直接依赖。**

所有外部模块应通过 `LumiCoreKit` 的 typealias 访问此包中的类型：

```swift
// ✅ 正确：通过 LumiCoreKit 访问
import LumiCoreKit

let coordinator = LumiCoreKit.GitAccessCoordinator

// ❌ 错误：不应直接依赖此包
import LumiComponentGit
```

## 包含模块

### GitComponent
- `GitComponent` - Git 功能组件（状态管理）

### GitAccessCoordinator
- `GitAccessCoordinator` - 全局 libgit2 访问串行化协调器
  - `perform(_:)` - async/await 形式执行
  - `performSync(_:)` - 同步执行
  - `queue` - 共享串行队列

## 设计说明

### 为什么需要 GitAccessCoordinator？

libgit2 的 `git_repository` / `git_index` 等对象不是线程安全的。并发访问可能导致：
- `EXC_BAD_ACCESS` 内存错误
- `EXC_BREAKPOINT` 延迟崩溃
- 数据损坏

`GitAccessCoordinator` 提供进程级单一串行队列，确保所有 libgit2 调用串行执行。

## 依赖

无外部依赖。

## 架构设计

```
┌─────────────────────────────────────────────┐
│            LumiCoreKit (门面)                │
│  ┌─────────────────────────────────────┐    │
│  │ GitExports.swift (typealias)          │    │
│  └─────────────────────────────────────┘    │
│                     ▲                        │
│     ┌───────────────┴───────────────┐       │
│     │                               │       │
│  GitComponent ───────── GitAccessCoordinator
│  (内部依赖)                   (内部依赖)      │
└─────────────────────────────────────────────┘
         ▲
         │ 只依赖这里
    ┌────┴────┐
    │ 外部模块 │
    │App, Chat│
    │ Plugins │
    └─────────┘
```