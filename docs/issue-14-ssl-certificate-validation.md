# Issue #14: 缺少 SSL/TLS 证书验证

**严重程度**: 🟠 High  
**状态**: Open  
**文件**: `LumiApp/Core/Services/LLM/LLMAPIService.swift`

---

## 问题描述

当前的网络请求可能没有严格验证 SSL/TLS 证书，存在中间人攻击（MITM）风险。

---

## 当前代码

```swift
class LLMAPIService: SuperLog, @unchecked Sendable {
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        self.session = URLSession(configuration: configuration)
        // 问题：使用默认配置，没有自定义证书验证
    }
}
```

---

## 安全风险

### 1. 中间人攻击

```
[用户设备] <---> [攻击者] <---> [API 服务器]
                    ↓
              截获 API Key
              截获对话内容
```

### 2. DNS 欺骗

- 攻击者伪造 DNS 响应
- 将请求重定向到恶意服务器

### 3. 证书伪造

- 自签名证书
- 过期证书
- 域名不匹配证书

### 4. 公共 WiFi 风险

- 咖啡馆、机场等公共网络
- 攻击者更容易实施 MITM

---

## 建议修复

### 1. 实现证书锁定（Certificate Pinning）

```swift
import Security

/// SSL Pinning 配置
class SSLPinningDelegate: NSObject, URLSessionDelegate {
    // 预置的公钥哈希（SHA256）
    private let pinnedPublicKeys: [String: [Data]] = [
        "api.openai.com": [
            // OpenAI 的公钥哈希（示例，需要从实际证书获取）
            Data(base64Encoded: "YOUR_OPENAI_PUBLIC_KEY_HASH")!
        ],
        "api.anthropic.com": [
            Data(base64Encoded: "YOUR_ANTHROPIC_PUBLIC_KEY_HASH")!
        ],
        // 其他供应商...
    ]
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let host = challenge.protectionSpace.host else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // 检查证书有效性
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)
        
        guard isValid else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // 检查证书锁定
        if let pinnedKeys = pinnedPublicKeys[host] {
            if verifyPublicKeyPin(serverTrust: serverTrust, pinnedKeys: pinnedKeys) {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        } else {
            // 没有锁定配置的域名，使用默认验证
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        }
    }
    
    /// 验证公钥锁定
    private func verifyPublicKeyPin(serverTrust: SecTrust, pinnedKeys: [Data]) -> Bool {
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        
        for i in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) else {
                continue
            }
            
            // 提取公钥
            guard let publicKey = SecCertificateCopyKey(certificate) else {
                continue
            }
            
            // 计算公钥哈希
            guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) else {
                continue
            }
            
            let hash = sha256(publicKeyData as Data)
            
            // 检查是否匹配
            if pinnedKeys.contains(hash) {
                return true
            }
        }
        
        return false
    }
    
    private func sha256(_ data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }
}
```

### 2. 使用带 Pinning 的 URLSession

```swift
class LLMAPIService: SuperLog, @unchecked Sendable {
    private nonisolated let session: URLSession
    private nonisolated let sslDelegate: SSLPinningDelegate
    
    init() {
        self.sslDelegate = SSLPinningDelegate()
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        
        self.session = URLSession(
            configuration: configuration,
            delegate: sslDelegate,
            delegateQueue: nil
        )
    }
}
```

### 3. 证书更新策略

```swift
/// 证书管理器
actor CertificateManager {
    /// 从服务器获取最新证书
    func fetchCertificates(for host: String) async throws -> [Data] {
        // 可以从 CDN 或备用服务器获取
        // 支持证书轮换
    }
    
    /// 检查证书是否即将过期
    func checkCertificateExpiry() async {
        // 提前预警即将过期的证书
    }
    
    /// 备用证书（用于紧急情况）
    func getBackupCertificates(for host: String) -> [Data] {
        // 返回备用证书
    }
}
```

### 4. 证书验证失败处理

```swift
struct SSLValidationError: Error {
    let reason: String
    let host: String
    let certificateDetails: String?
}

// 在 UI 中显示
class SSLValidationHandler {
    func handleValidationError(_ error: SSLValidationError) {
        // 记录安全事件
        SecurityLogger.log(.sslValidationFailed(error))
        
        // 通知用户
        NotificationCenter.default.post(
            name: .securityAlert,
            object: nil,
            userInfo: [
                "type": "ssl_validation_failed",
                "host": error.host,
                "reason": error.reason
            ]
        )
        
        // 阻止请求继续
    }
}
```

### 5. 开发环境例外

```swift
class SSLPinningDelegate: NSObject, URLSessionDelegate {
    #if DEBUG
    private let allowInvalidCertificates = true  // 仅开发环境
    #else
    private let allowInvalidCertificates = false
    #endif
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // ... 前面的验证代码 ...
        
        #if DEBUG
        // 开发环境允许本地测试证书
        if allowInvalidCertificates && host.contains("localhost") {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            return
        }
        #endif
        
        // 生产环境严格验证
    }
}
```

---

## 测试清单

- [ ] 测试正常证书验证通过
- [ ] 测试自签名证书被拒绝
- [ ] 测试过期证书被拒绝
- [ ] 测试域名不匹配被拒绝
- [ ] 测试中间人攻击被检测
- [ ] 测试证书更新流程
- [ ] 测试备用证书机制

---

## 工具推荐

1. **Charles Proxy** - 测试 MITM
2. **mitmproxy** - 自动化安全测试
3. **OpenSSL** - 获取证书信息
   ```bash
   openssl s_client -connect api.openai.com:443 | openssl x509 -pubkey -noout
   ```

---

## 修复优先级

高 - 缺少 SSL 验证可能导致：
- API Key 被截获
- 对话内容泄露
- 中间人攻击

---

*创建时间: 2026-03-13*