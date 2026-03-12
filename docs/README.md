# Lumi 项目 Issues 索引

> 最后更新：2026-03-12

---

## 📊 问题统计

| 严重程度 | 数量 |
|----------|------|
| 🔴 Critical | 9 |
| 🟠 High | 2 |
| 🟡 Medium | 4 |
| 🟢 Low | 2 |
| **总计** | **17** |

---

## 🔴 Critical（需立即修复）

| # | Issue | 文件 | 相关问题 |
|---|-------|------|----------|
| 001 | ChatMessage force-unwrap 崩溃 | `issue-001-chatmessage-force-unwrap-crash.md` | try! 强制解包 |
| 005 | 系统性 NotificationCenter 泄漏 | `issue-005-systematic-notificationcenter-observers-leak.md` | 内存泄漏 |
| 006 | SwiftData actor 隔离违规 | `issue-006-critical-swiftdata-actor-isolation-violation.md` | 并发安全 |
| 008 | API Key 未安全存储 | `issue-008-api-key-secure-storage.md` | 安全风险 |
| 010 | Coordinator Task 泄漏 | `issue-010-coordinator-task-leak.md` | 内存泄漏 |
| 014 | TaskGroup 取消与错误传播缺失 | `issue-014-taskgroup-cancellation-error-propagation.md` | 并发安全 |
| 015 | ConversationTurnViewModel 资源泄漏 | `issue-015-conversation-turn-viewmodel-resource-leak.md` | 内存泄漏 |
| **016** | **AsyncStream Continuation 资源泄漏** | `issue-016-asyncstream-continuation-resource-leak.md` | **内存泄漏** |
| **017** | **ToolService NotificationCenter 泄漏** | `issue-017-toolservice-notificationcenter-leak.md` | **内存泄漏** |

---

## 🟠 High（近期修复）

| # | Issue | 文件 | 相关问题 |
|---|-------|------|----------|
| 011 | Actor Plugin 无法管理观察者 | `issue-011-actor-plugin-notification-leak.md` | 设计问题 |
| **018** | **ChatMessageEntity 强制解包崩溃** | `issue-018-chatmessage-entity-force-unwrap-crash.md` | **崩溃风险** |

---

## 🟡 Medium（计划修复）

| # | Issue | 文件 | 相关问题 |
|---|-------|------|----------|
| 002 | @unchecked Sendable 并发安全 | `issue-002-systematic-concurrency-safety-unchecked-sendable.md` | 并发 |
| 003 | TurnContexts 内存泄漏 | `issue-003-memory-leak-turn-contexts.md` | 内存泄漏 |
| 004 | 日志敏感数据泄露 | `issue-004-verbose-logging-sensitive-data-leak.md` | 安全 |
| 012 | IPCConnection delegate 循环引用 | `issue-012-ipc-connection-delegate-retain-cycle.md` | 内存泄漏 |

---

## 🟢 Low（建议改进）

| # | Issue | 文件 | 相关问题 |
|---|-------|------|----------|
| 007 | StreamChunk middleware 短路 | `issue-007-streamchunk-middleware-short-circuit.md` | 功能 |
| 013 | print 语句残留 | `issue-013-print-statements-in-production.md` | 代码质量 |

---

## 📂 按类别分组

### 🔒 安全类
- Issue #004: 日志敏感数据泄露
- Issue #006: SwiftData actor 隔离违规
- Issue #008: API Key 未安全存储

### 🧠 内存管理类
- Issue #003: TurnContexts 内存泄漏
- Issue #005: 系统性 NotificationCenter 泄漏
- Issue #010: Coordinator Task 泄漏
- Issue #011: Actor Plugin 无法管理观察者
- Issue #012: IPCConnection delegate 循环引用
- Issue #015: ConversationTurnViewModel 资源泄漏
- **Issue #016: AsyncStream Continuation 资源泄漏** 🆕
- **Issue #017: ToolService NotificationCenter 泄漏** 🆕

### ⚡ 并发类
- Issue #002: @unchecked Sendable 并发安全
- Issue #006: SwiftData actor 隔离违规
- Issue #014: TaskGroup 取消与错误传播缺失

### 🐛 崩溃/功能类
- Issue #001: ChatMessage force-unwrap 崩溃
- Issue #007: StreamChunk middleware 短路
- **Issue #018: ChatMessageEntity 强制解包崩溃** 🆕

### 🔧 代码质量类
- Issue #013: print 语句残留
- Issue #011: Actor Plugin 无法管理观察者

---

## 🚀 修复路线图

### Phase 1: P0 - 立即修复（Critical）
- [ ] Issue #001: 修复 ChatMessage force-unwrap
- [ ] Issue #005: 修复 NotificationCenter 泄漏
- [ ] Issue #006: 修复 SwiftData actor 隔离
- [ ] Issue #008: 实现 Keychain 存储
- [ ] Issue #010: 添加 Coordinator deinit
- [ ] Issue #014: 修复 TaskGroup 取消与错误传播
- [ ] Issue #015: 修复 ConversationTurnViewModel 资源泄漏
- [ ] **Issue #016: 修复 AsyncStream Continuation 泄漏** 🆕
- [ ] **Issue #017: 修复 ToolService NotificationCenter 泄漏** 🆕

### Phase 2: P1 - 近期修复（High + Medium）
- [ ] Issue #011: 重构 Actor Plugin
- [ ] **Issue #018: 修复 ChatMessageEntity 强制解包** 🆕
- [ ] Issue #002: 审计 @unchecked Sendable
- [ ] Issue #003: 修复 TurnContexts 泄漏
- [ ] Issue #004: 修复日志敏感数据
- [ ] Issue #012: 修复 delegate 循环

### Phase 3: P2 - 计划改进（Low）
- [ ] Issue #007: 修复 middleware 短路
- [ ] Issue #013: 清理 print 语句

---

## 🔧 常用审计命令

```bash
# 统计 Swift 文件数量
find LumiApp -name "*.swift" | wc -l

# 查找 try! 使用
grep -rn "try!" --include="*.swift" LumiApp/

# 查找 as! 强制类型转换
grep -rn "as!" --include="*.swift" LumiApp/

# 统计 NotificationCenter addObserver/removeObserver
grep -rn "addObserver" --include="*.swift" LumiApp/ | wc -l
grep -rn "removeObserver" --include="*.swift" LumiApp/ | wc -l

# 查找 print 语句
grep -rn "print(" --include="*.swift" LumiApp/ | grep -v "debugPrint"

# 查找 actor Plugin
grep -rn "^actor.*Plugin" --include="*.swift" LumiApp/Plugins/ | wc -l

# 查找 TaskGroup 使用
grep -rn "withTaskGroup\|withThrowingTaskGroup" --include="*.swift" LumiApp/

# 查找 Task.detached 使用
grep -rn "Task\.detached" --include="*.swift" LumiApp/

# 查找 Task.checkCancellation 使用
grep -rn "Task\.checkCancellation" --include="*.swift" LumiApp/

# 查找 AsyncStream 使用
grep -rn "AsyncStream\|AsyncThrowingStream" --include="*.swift" LumiApp/

# 查找 Continuation 使用
grep -rn "Continuation" --include="*.swift" LumiApp/

# 查找 deinit 实现
grep -rn "deinit" --include="*.swift" LumiApp/

# 查找 @unchecked Sendable 使用
grep -rn "@unchecked Sendable" --include="*.swift" LumiApp/

# 查找 fatalError 调用
grep -rn "fatalError" --include="*.swift" LumiApp/

# 查找 UserDefaults 存储 API Key
grep -rn "UserDefaults.*apiKey\|apiKey.*UserDefaults" --include="*.swift" LumiApp/
```

---

## 📝 Issue 模板

```markdown
# Issue #XXX: [严重程度] - [简短描述]

## 📋 问题概述

[问题描述]

## 🔴 严重程度：[Critical/High/Medium/Low]

**风险等级**: ⚠️ 可能导致：
- [影响1]
- [影响2]

**优先级**: P[0-2]

---

## 📍 问题位置

### 文件: `LumiApp/[路径]`

| 属性 | 值 |
|------|-----|
| 行号 | X-Y |
| 问题 | [问题描述] |

---

## 🐛 问题分析

### 问题代码

```swift
// 问题代码示例
```

### 根因分析

[详细分析]

---

## ✅ 修复方案

### 方案 1: [名称]（推荐）

```swift
// 修复代码
```

---

## 🔄 相关 Issue

- Issue #XXX: [相关问题描述]

---

**创建日期**: YYYY-MM-DD
**更新日期**: YYYY-MM-DD
**创建者**: [作者]
**标签**: `bug`, `[其他标签]`
```

---

## 🆕 最近新增

| Issue | 日期 | 描述 |
|-------|------|------|
| #016 | 2026-03-12 | AsyncStream Continuation 资源泄漏 - ViewModel 未正确关闭流 |
| #017 | 2026-03-12 | ToolService NotificationCenter 泄漏 - 服务未移除观察者 |
| #018 | 2026-03-12 | ChatMessageEntity 强制解包崩溃 - 数据损坏时应用崩溃 |