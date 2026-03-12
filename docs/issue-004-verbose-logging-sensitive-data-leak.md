# Issue: 生产环境默认开启详细日志 - 敏感数据泄漏风险

## 📋 问题概述

项目中存在 64 处 `verbose = true` 或 `verbose >= 1` 的详细日志设置，遍布核心服务和 LLM 服务。这些日志在生产环境下默认开启，导致敏感信息（API 密钥、用户对话内容、请求体等）被记录到系统日志，存在严重的数据泄漏风险。

---

## 🔴 严重程度：Critical (安全漏洞)

**风险等级**: ⚠️ 生产环境敏感数据泄漏

**CVSS 评分**: 7.5 (High)

---

## 📍 问题位置

### 核心问题文件

**LLM 服务**（最严重）:
- `LumiApp/Core/Services/LLM/LLMAPIService.swift:11` - `verbose = true`
- `LumiApp/Core/Services/LLM/LLMService.swift:29` - `verbose = 1`
- `LumiApp/Core/Services/LLM/AnthropicProvider.swift:34` - `verbose = true`
- `LumiApp/Core/Services/LLM/ZhipuProvider.swift:12` - `verbose = true`
- `LumiApp/Core/Services/LLM/AliyunProvider.swift:14` - `verbose = true`

**其他关键服务**:
- `LumiApp/Core/Services/Tools/ToolExecutionService.swift:31` - `verbose = true`
- `LumiApp/Core/Services/ChatHistoryService.swift:54` - `verbose = true`
- `LumiApp/Core/Services/Workers/WorkerAgentService.swift:10` - `verbose = true`

**ViewModels**:
- `LumiApp/Core/ViewModels/ConversationTurnViewModel.swift:37` - `verbose = true`
- `LumiApp/Core/ViewModels/MessageSenderViewModel.swift:25` - `verbose = true`
- `LumiApp/Core/ViewModels/ToolsViewModel.swift:15` - `verbose = true`

**总计**: 约 64 处

---

## 🐛 问题分析

### 为什么这是严重问题？

#### 1. API 密钥泄漏

**问题代码** (`LLMAPIService.swift:150-160`):
```swift
if Self.verbose {
    os_log("\(self.t)LLM 请求头:")
    for (key, value) in headers {
        let maskedValue = key.lowercased().contains("key") || key.lowercased().contains("auth")
            ? String(value.prefix(10)) + "..."  // ❌ 只遮蔽前 10 个字符，仍然泄漏部分密钥
            : value
        os_log("\(self.t)  \(key): \(maskedValue)")
    }
}
```

**风险**:
- API 密钥前 10 个字符被记录（如 `sk-proj-ab...`）
- 攻击者可以通过部分密钥推断完整密钥
- 请求体中可能包含完整密钥

#### 2. 用户对话内容泄漏

**问题代码** (`LLMAPIService.swift:90-110`):
```swift
if Self.verbose {
    var logMessage = "\(self.t)🚀 发送流式请求到：\(url.absoluteString)\n"
    
    if let bodyData = request.httpBody,
       let bodyString = String(data: bodyData, encoding: .utf8) {
        // ❌ 完整的请求体被记录，包含用户对话内容
        logMessage += "📦 请求体 (\(formattedSize))：\n\(bodyString)\n"
    }
    
    os_log(logMessage)
}
```

**风险**:
- 用户的完整对话历史被记录到系统日志
- 敏感信息（密码、个人信息、商业机密）可能泄漏
- 违反隐私保护法规（GDPR、CCPA 等）

#### 3. 日志持久化

**问题**:
- macOS 系统日志默认持久化到磁盘
- 日志可能被备份到 iCloud
- 恶意软件或攻击者可以读取系统日志
- 日志可能被提交到错误跟踪系统

---

## 🔍 影响范围

### 受影响的功能

1. **所有 LLM API 调用**:
   - OpenAI (GPT-4, GPT-3.5)
   - Anthropic (Claude)
   - DeepSeek
   - 智谱 (Zhipu)
   - 阿里云 (Aliyun)

2. **工具执行**:
   - 工具调用参数和结果
   - 文件操作
   - 命令执行

3. **用户数据**:
   - 对话历史
   - 项目文件路径
   - 设置信息

---

## ✅ 建议修复方案

### 方案 1: 使用编译条件（推荐）

```swift
// 在 SuperLog 基类或每个服务中
#if DEBUG
nonisolated static let verbose = true
#else
nonisolated static let verbose = false
#endif
```

**优点**:
- 生产环境自动关闭
- 开发环境保持调试能力
- 零运行时开销

### 方案 2: 使用环境变量

```swift
class LLMAPIService: SuperLog {
    nonisolated static let verbose: Bool = {
        // 检查环境变量或配置
        ProcessInfo.processInfo.environment["LUMI_VERBOSE_LOGGING"] == "true"
    }()
}
```

### 方案 3: 运行时配置（灵活但需要额外实现）

```swift
class LogConfig: ObservableObject {
    static let shared = LogConfig()
    
    @Published var verbose: Bool = false
    
    private init() {
        // 可以从配置文件或 UserDefaults 读取
        #if DEBUG
        verbose = true
        #endif
    }
}
```

### 方案 4: 完全移除敏感日志（最安全）

```swift
// ❌ 移除这类日志
if Self.verbose {
    os_log("API Key: \(apiKey)")
    os_log("Request body: \(body)")
}

// ✅ 只保留非敏感信息
if Self.verbose {
    os_log("发送请求到 \(provider)")
    os_log("请求成功，耗时 \(latency)ms")
}
```

---

## 📝 修复优先级

### Phase 1: 立即修复（P0）

1. **禁用生产环境详细日志**:
   ```swift
   #if DEBUG
   nonisolated static let verbose = true
   #else
   nonisolated static let verbose = false
   #endif
   ```

2. **移除 API 密钥日志**:
   - 完全移除记录 API 密钥的代码
   - 不记录任何认证相关字段

### Phase 2: 短期优化（P1）

1. **审计所有日志语句**:
   - 检查所有 `os_log` 调用
   - 确保不记录敏感信息

2. **实现日志脱敏**:
   - 对敏感字段进行脱敏处理
   - 使用 `[REDACTED]` 替代敏感值

### Phase 3: 长期改进（P2）

1. **建立日志规范**:
   - 定义什么可以记录、什么不能记录
   - 添加代码审查检查项

2. **实现日志审查工具**:
   - 自动检测敏感信息
   - CI/CD 集成

---

## 🔒 安全建议

### 对于已发布版本

1. **通知用户**:
   - 发布安全公告
   - 建议用户轮换 API 密钥

2. **提供清理工具**:
   - 清理系统日志
   - 提供日志清理脚本

### 对于开发过程

1. **代码审查**:
   - 检查所有新增日志语句
   - 禁止记录敏感信息

2. **静态分析**:
   - 添加敏感信息检测规则
   - CI/CD 自动检测

---

## 📊 相关文件统计

```bash
# 查找所有 verbose 设置
grep -rn "verbose = true\|verbose = 1\|verbose = 2" --include="*.swift" LumiApp/ | wc -l
# 结果: 64

# 查找 LLM 服务中的日志
grep -rn "os_log.*apiKey\|os_log.*key" --include="*.swift" LumiApp/Core/Services/LLM/
# 结果: 多处

# 查找请求体日志
grep -rn "os_log.*body\|os_log.*请求体" --include="*.swift" LumiApp/Core/Services/LLM/
# 结果: 多处
```

---

## 🎯 验证方法

### 测试步骤

1. 构建生产版本:
   ```bash
   xcodebuild -configuration Release
   ```

2. 运行应用并执行 LLM 请求

3. 检查系统日志:
   ```bash
   log show --predicate 'subsystem == "com.coffic.lumi"' --last 5m
   ```

4. 验证没有敏感信息

---

## 📚 参考资源

- [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)
- [Apple Unified Logging and Activity Tracing](https://developer.apple.com/documentation/os/logging)
- [GDPR Data Protection](https://gdpr.eu/data-protection/)

---

**创建日期**: 2026-03-12
**创建者**: DevAssistant (自动分析生成)
**标签**: `security`, `data-leak`, `api-key`, `logging`, `high-priority`, `pii`
**CVE 编号**: 待申请
**影响版本**: 所有已发布版本