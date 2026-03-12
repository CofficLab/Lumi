# Issue #006: 严重安全隐患 - API Key 未使用安全存储

## 📋 问题概述

LLM 供应商的 API Key 存储方式存在严重安全隐患，可能导致用户凭证被泄露。

---

## 🔴 严重程度：严重 (Critical)

**风险等级**: ⚠️ 用户凭证可能被盗用，导致经济损失

---

## 📍 问题位置

**涉及文件**: 
- `LumiApp/Core/Services/LLM/LLMConfig.swift`
- `LumiApp/Core/Services/LLM/AnthropicProvider.swift`
- `LumiApp/Core/Services/LLM/OpenAIProvider.swift`
- `LumiApp/Core/Services/LLM/DeepSeekProvider.swift`
- `LumiApp/Core/Services/LLM/ZhipuProvider.swift`
- `LumiApp/Core/Services/LLM/AliyunProvider.swift`

---

## 🐛 问题分析

### 当前架构

项目支持 5 个 LLM 供应商：
- **Anthropic** (Claude)
- **OpenAI** (GPT-4, GPT-3.5)
- **DeepSeek**
- **智谱** (Zhipu)
- **阿里云** (Aliyun)

所有供应商都需要 API Key 进行身份验证。

### 风险场景

1. **UserDefaults 存储风险**
   - 如果 API Key 存储在 `UserDefaults`，任何能访问应用沙盒的进程都可以读取
   - 未加密的明文存储

2. **文件存储风险**
   - 如果存储在普通文件中，缺乏加密保护
   - 可能被恶意软件扫描读取

3. **应用共享风险**
   - 如果应用被恶意注入或 hook，API Key 可能被窃取

### 影响范围

- 用户支付凭证（API Key 按调用量计费）
- 可能导致用户账户被滥用
- 经济损失责任

---

## ✅ 建议修复方案

### 方案 1: 使用 Keychain 存储（推荐）

```swift
import Security

final class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.lumi.app"
    
    func saveAPIKey(_ key: String, for providerId: String) throws {
        let data = Data(key.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerId,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // 删除已存在的项
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    func getAPIKey(for providerId: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    func deleteAPIKey(for providerId: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerId
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
}
```

### 方案 2: 使用 macOS Keychain Access Group（多应用共享）

```swift
// 在 entitlements 中添加 keychain-access-groups
// 然后使用 access group 进行存储
let accessGroup = "$(AppIdentifierPrefix)com.lumi.shared"
```

---

## 📝 修复优先级

| 优先级 | 任务 | 预计工作量 |
|--------|------|-----------|
| **P0** | 实现 KeychainManager 存储 API Key | 2-3 小时 |
| **P1** | 迁移现有 API Key 到 Keychain | 1 小时 |
| **P1** | 添加 API Key 读取时的安全验证 | 1 小时 |
| **P2** | 实现 API Key 自动轮换机制 | 4-6 小时 |

---

## 🔍 相关检查

建议检查现有代码中 API Key 的使用方式：

```bash
# 查找可能的 API Key 存储
grep -rn "apiKey\|APIKey" --include="*.swift" LumiApp/

# 查找 UserDefaults 存储
grep -rn "UserDefaults" --include="*.swift" LumiApp/ | grep -i "key\|token\|secret"
```

---

## 🔄 相关 Issue

- **Issue #001**: ChatMessageEntity 强制解包崩溃
- **Issue #002**: 并发安全隐患 - @unchecked Sendable

---

**创建日期**: 2026-03-12
**更新日期**: 2026-03-12
**创建者**: DevAssistant (自动分析生成)
**标签**: `security`, `critical`, `api-key`, `keychain`