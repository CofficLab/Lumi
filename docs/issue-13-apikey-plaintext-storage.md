# Issue #13: API Key 明文存储风险

**严重程度**: 🔴 Critical  
**状态**: Open  
**文件**: `LumiApp/Core/Services/LLM/*.swift`, `LLMConfig` 相关文件

---

## 问题描述

API Key 等敏感凭据可能以明文形式存储在内存或配置文件中，存在安全风险。

---

## 安全风险

### 1. 内存泄露

```swift
// 当前可能的实现
struct LLMConfig {
    let apiKey: String  // 明文存储在内存中
}

// 风险：
// - 内存转储可读取
// - 调试器可查看
// - 崩溃日志可能包含
// - 内存扫描攻击
```

### 2. 持久化存储风险

```swift
// 可能的不安全存储
UserDefaults.standard.set(apiKey, forKey: "api_key")  // 明文存储

// 风险：
// - 文件系统可访问
// - 备份中包含
// - 其他应用可能读取（越狱设备）
```

### 3. 日志泄露

```swift
// 之前的 Issue 提到
print("API Key: \(apiKey)")  // 日志中泄露
```

### 4. 网络传输

```swift
// 虽然使用 HTTPS，但仍有风险
request.setValue(apiKey, forHTTPHeaderField: "Authorization")
```

---

## 建议修复

### 1. 使用 Keychain 存储

```swift
import Security

/// Keychain 服务
actor KeychainService {
    static let shared = KeychainService()
    
    private let service = "com.coffic.lumi"
    
    /// 保存 API Key
    func saveAPIKey(_ key: String, for provider: String) throws {
        let account = "api_key_\(provider)"
        
        // 先删除旧的
        try? deleteAPIKey(for: provider)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: key.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// 读取 API Key
    func getAPIKey(for provider: String) throws -> String? {
        let account = "api_key_\(provider)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
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
    
    /// 删除 API Key
    func deleteAPIKey(for provider: String) throws {
        let account = "api_key_\(provider)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
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
    case notFound
}
```

### 2. 内存保护

```swift
/// 安全字符串包装器
class SecureString {
    private var buffer: [UInt8]
    private let length: Int
    
    init(_ string: String) {
        let data = string.data(using: .utf8)!
        self.length = data.count
        self.buffer = [UInt8](unsafeUninitializedCapacity: length) { ptr, count in
            data.withUnsafeBytes { dataPtr in
                ptr.initialize(from: dataPtr.baseAddress!, count: length)
            }
            count = length
        }
    }
    
    deinit {
        // 清零内存
        memset_s(&buffer, buffer.count, 0, buffer.count)
    }
    
    /// 临时获取字符串（使用后立即清零）
    func withUnsafeString<T>(_ body: (String) throws -> T) rethrows -> T {
        defer {
            // 清零临时缓冲区
            memset_s(&buffer, buffer.count, 0, buffer.count)
        }
        
        let string = String(bytes: buffer, encoding: .utf8)!
        return try body(string)
    }
    
    /// 检查是否匹配（不暴露实际值）
    func matches(_ other: String) -> Bool {
        guard let otherData = other.data(using: .utf8),
              otherData.count == length else {
            return false
        }
        
        let otherBytes = [UInt8](otherData)
        var result = true
        
        for i in 0..<length {
            if buffer[i] != otherBytes[i] {
                result = false
            }
        }
        
        return result
    }
}

// 使用示例
let secureKey = SecureString("sk-xxxxx")
secureKey.withUnsafeString { key in
    // 使用 key
    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
}
// 使用后自动清零
```

### 3. 安全的 LLMConfig

```swift
/// 安全的配置存储
struct SecureLLMConfig {
    let providerId: String
    let model: String
    private let secureKey: SecureString?
    
    var apiKey: String? {
        guard let secureKey = secureKey else { return nil }
        return secureKey.withUnsafeString { $0 }
    }
    
    init(providerId: String, model: String, apiKey: String?) {
        self.providerId = providerId
        self.model = model
        self.secureKey = apiKey.map { SecureString($0) }
    }
    
    /// 从 Keychain 加载
    static func load(for providerId: String, model: String) async throws -> SecureLLMConfig {
        let apiKey = try await KeychainService.shared.getAPIKey(for: providerId)
        return SecureLLMConfig(providerId: providerId, model: model, apiKey: apiKey)
    }
    
    /// 保存到 Keychain
    func save() async throws {
        guard let key = apiKey else { return }
        try await KeychainService.shared.saveAPIKey(key, for: providerId)
    }
}
```

### 4. 配置视图安全处理

```swift
/// API Key 输入视图
struct APIKeyInputView: View {
    let provider: String
    @State private var apiKey: String = ""
    @State private var showKey: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Key")
                .font(.headline)
            
            HStack {
                if showKey {
                    TextField("Enter API Key", text: $apiKey)
                        .textContentType(.password)
                } else {
                    SecureField("Enter API Key", text: $apiKey)
                }
                
                Button(action: { showKey.toggle() }) {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                }
            }
            
            HStack {
                Button("Save") {
                    Task {
                        try? await KeychainService.shared.saveAPIKey(apiKey, for: provider)
                        apiKey = ""  // 清空内存中的副本
                    }
                }
                
                Button("Clear") {
                    Task {
                        try? await KeychainService.shared.deleteAPIKey(for: provider)
                    }
                }
            }
        }
    }
}
```

### 5. 应用生命周期处理

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // 应用退出时清理敏感数据
        Task {
            await clearSensitiveData()
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // 应用激活时重新加载配置
    }
    
    func applicationWillResignActive(_ notification: Notification) {
        // 应用失去焦点时清理内存中的敏感数据
        Task {
            await clearSensitiveDataFromMemory()
        }
    }
    
    private func clearSensitiveDataFromMemory() async {
        // 清理内存中的敏感数据
        // 重新从 Keychain 加载
    }
}
```

---

## 检查清单

- [ ] 确认所有 API Key 都存储在 Keychain
- [ ] 确认没有在 UserDefaults 中存储敏感信息
- [ ] 确认日志中不会打印 API Key
- [ ] 确认内存中的敏感数据使用后立即清零
- [ ] 确认应用退出时清理敏感数据
- [ ] 确认崩溃日志不包含敏感数据

---

## 修复优先级

最高 - API Key 泄露可能导致：
- 账户被盗用
- 产生巨额费用
- 数据泄露

---

*创建时间: 2026-03-13*