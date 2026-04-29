# ModelPreferencePlugin 日志输出示例

## 📋 日志格式规范

按照 `SuperLog` 协议和 `os.Logger`，日志格式为：
```
[QoS] | <emoji> <类名> | <消息>
```

### QoS 标识说明
- 🔥 `[UI]` - UserInteractive (主线程)
- 2️⃣ `[IN]` - UserInitiated
- 3️⃣ `[DF]` - Default
- 4️⃣ `[UT]` - Utility
- 5️⃣ `[BG]` - Background

## 🔍 实际日志输出示例

### 1. 应用启动时加载项目偏好

```
[UI] | 🎯 ModelPreferenceRootView    | 📂 已加载项目 'Lumi' 的模型偏好：anthropic - claude-3-5-sonnet-20241022 (更新于：2024-03-24 09:30:00)
[UI] | 💾 ModelPreferenceStore       | 读取项目偏好：Lumi -> anthropic / claude-3-5-sonnet-20241022
```

### 2. 用户选择新模型

```
[UI] | 🎯 ModelPreferenceRootView    | 💾 已保存项目 'Lumi' 的模型偏好：openai - gpt-4-turbo-preview
[UI] | 💾 ModelPreferenceStore       | 保存项目偏好：Lumi -> openai / gpt-4-turbo-preview
```

### 3. 切换项目

```
[UI] | 🎯 ModelPreferenceRootView    | 📂 已加载项目 'MyApp' 的模型偏好：anthropic - claude-3-opus (更新于：2024-03-23 14:20:00)
[UI] | 💾 ModelPreferenceStore       | 读取项目偏好：MyApp -> anthropic / claude-3-opus
```

### 4. 切换到没有保存偏好的项目

```
[UI] | 🎯 ModelPreferenceRootView    | 📂 项目 'NewProject' 没有保存的模型偏好
```

### 5. 清除项目选择

```
[UI] | 🎯 ModelPreferenceRootView    | 📁 已清除项目，不加载模型偏好
```

### 6. 用户已手动选择模型，不覆盖

```
[UI] | 🎯 ModelPreferenceRootView    | 📂 项目 'Lumi' 有保存的模型偏好 (anthropic - claude-3-5-sonnet)，但用户已手动选择其他模型，不覆盖
```

## 📊 日志层级

### ModelPreferenceRootView (🎯)
- **Logger**: `os.Logger(subsystem: "com.coffic.lumi", category: "model-preference.root-view")`
- 监听模型变化和项目切换
- 触发保存和加载操作
- 输出高层逻辑信息

### ModelPreferencePlugin (🎯)
- **Logger**: `os.Logger(subsystem: "com.coffic.lumi", category: "model-preference.plugin")`
- 提供保存和加载 API
- 协调 ModelPreferenceStore
- 输出操作结果

### ModelPreferenceStore (💾)
- **Logger**: `os.Logger(subsystem: "com.coffic.lumi", category: "model-preference.store")`
- 实际的文件读写操作
- 原子写入保证
- 输出底层操作详情

## 🎨 日志 Emoji 说明

| Emoji | 类别 | 说明 |
|-------|------|------|
| 🎯 | ModelPreferenceRootView/Plugin | 业务逻辑层 |
| 💾 | ModelPreferenceStore | 数据持久化层 |
| 📂 | 读取操作 | 从磁盘加载数据 |
| 📁 | 清除操作 | 清除项目选择 |
| ⚠️ | 警告 | 跳过操作 |
| ❌ | 错误 | 操作失败 |

## 📝 日志开关

通过修改 `verbose` 属性控制日志输出：

```swift
// ModelPreferencePlugin.swift
nonisolated static let verbose: Bool = true  // 开启日志
nonisolated static let verbose: Bool = false // 关闭日志
```

## 🔍 查看日志的方法

### 方法 1：Xcode Console
在 Xcode 中运行应用，查看控制台输出

### 方法 2：Console.app
1. 打开 Console.app
2. 选择设备
3. 过滤进程：`Lumi`
4. 搜索关键词：
   - `model-preference` (所有相关日志)
   - `model-preference.root-view` (仅 RootView 日志)
   - `model-preference.plugin` (仅 Plugin 日志)
   - `model-preference.store` (仅 Store 日志)

### 方法 3：终端命令
```bash
# 实时查看模型偏好相关日志
log stream --predicate 'subsystem == "com.coffic.lumi" AND category BEGINSWITH "model-preference"' --level info

# 只查看 RootView 日志
log stream --predicate 'category == "model-preference.root-view"' --level info

# 只查看 Store 日志
log stream --predicate 'category == "model-preference.store"' --level info
```

## 🎯 典型场景日志流程

### 场景：用户在项目 A 中选择模型，然后切换到项目 B

```
时间线：
T0: 应用启动
T1: 加载项目 A 的偏好
T2: 用户选择新模型
T3: 保存到项目 A
T4: 切换到项目 B
T5: 加载项目 B 的偏好

日志输出：
[T0] [UI] | 🎯 ModelPreferenceRootView    | 📂 已加载项目 'ProjectA' 的模型偏好：anthropic - claude-3-5-sonnet
[T0] [UI] | 💾 ModelPreferenceStore       | 读取项目偏好：ProjectA -> anthropic / claude-3-5-sonnet

[T2] [UI] | 🎯 ModelPreferenceRootView    | 💾 已保存项目 'ProjectA' 的模型偏好：openai - gpt-4-turbo
[T2] [UI] | 💾 ModelPreferenceStore       | 保存项目偏好：ProjectA -> openai / gpt-4-turbo

[T4] [UI] | 🎯 ModelPreferenceRootView    | 📂 已加载项目 'ProjectB' 的模型偏好：openai - gpt-4
[T4] [UI] | 💾 ModelPreferenceStore       | 读取项目偏好：ProjectB -> openai / gpt-4
```

## ⚙️ 调试技巧

### 1. 按 Category 过滤

```bash
# 所有模型偏好日志
log stream --predicate 'category BEGINSWITH "model-preference"'

# 只看 RootView
log stream --predicate 'category == "model-preference.root-view"'

# 只看 Store
log stream --predicate 'category == "model-preference.store"'
```

### 2. 按 Emoji 过滤

```bash
# 保存操作
log stream --predicate 'category BEGINSWITH "model-preference"' | grep "💾"

# 加载操作
log stream --predicate 'category BEGINSWITH "model-preference"' | grep "📂"

# 错误日志
log stream --predicate 'category BEGINSWITH "model-preference"' | grep "❌"
```

### 3. 在 Xcode 中过滤

在 Xcode Console 的过滤栏中输入：
- `model-preference` - 显示所有相关日志
- `💾` - 只显示保存操作
- `📂` - 只显示加载操作
- `❌` - 只显示错误

## 📦 Logger 定义示例

每个组件内部定义自己的静态 logger：

```swift
struct ModelPreferenceRootView: View, SuperLog {
    nonisolated static let emoji: String { "🎯" }
    nonisolated static let verbose: Bool { ModelPreferencePlugin.verbose }
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", 
        category: "model-preference.root-view"
    )
    
    // 使用方式
    if Self.verbose {
        Self.logger.info("\(self.t)💾 已保存项目...")
    }
}
```

## 🔐 日志级别说明

| 级别 | 方法 | 用途 |
|------|------|------|
| **info** | `logger.info()` | 正常操作信息（默认） |
| **debug** | `logger.debug()` | 调试信息（默认不显示） |
| **error** | `logger.error()` | 错误信息（始终显示） |
| **warning** | `logger.warning()` | 警告信息 |
| **fault** | `logger.fault()` | 严重故障 |

当前实现主要使用 `info` 级别，通过 `verbose` 开关控制是否输出。
