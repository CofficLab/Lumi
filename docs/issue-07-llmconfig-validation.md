# Issue #7: 缺少 LLMConfig 验证

**严重程度**: 🟡 Medium  
**状态**: Open  
**涉及文件**: 
- `LumiApp/Core/Entities/LLMConfig.swift` (未找到源码)

---

## 问题描述

未找到 `LLMConfig` 模型的完整源码，无法确认是否存在以下安全验证：
- API Key 格式验证
- 配置格式校验
- 敏感信息加密存储

## 问题分析

LLMConfig 通常包含：
- API Key / API Secret
- API Endpoint URL
- Model 名称
- Temperature、Max tokens 等参数

如果缺少验证，可能导致：
1. 无效的 API Key 导致应用崩溃
2. 敏感凭据以明文存储
3. 配置错误难以诊断

## 建议修复

1. **API Key 格式验证**
   ```swift
   struct LLMConfig {
       var apiKey: String {
           didSet {
               guard isValidAPIKey(apiKey) else {
                   throw ConfigError.invalidAPIKey
               }
           }
       }
       
       private func isValidAPIKey(_ key: String) -> Bool {
           // 根据不同 provider 验证格式
           return key.hasPrefix("sk-") || key.hasPrefix("sk-proj-")
       }
   }
   ```

2. **安全的配置存储**
   - 使用 Keychain 存储 API Key
   - 避免明文保存到 UserDefaults 或文件

3. **配置完整性检查**
   - 启动时验证所有必要配置
   - 提供清晰的错误提示

## 修复优先级

中 - 影响安全性和用户体验