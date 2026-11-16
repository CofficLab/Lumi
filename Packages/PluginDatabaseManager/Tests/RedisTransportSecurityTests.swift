import Foundation
import Network
import Testing
@testable import DatabaseManagerPlugin

/// Redis 必须按用户选择的 SSL 模式建立传输层，而非恒用明文（#273）。
///
/// ## 回归背景（真实用户缺陷 #273）
///
/// `RedisDriver.connect` 此前丢弃 `config.sslOption`，`RedisConnection.init` 恒用
/// `NWConnection(..., using: .tcp)`，即便用户选择 require/verify-full 也明文发送 AUTH，
/// 泄露凭据。修复后校验强度与 `TLSSupport.makeTLSConfiguration` 一致：
/// disable/nil 明文；prefer TLS+可回退；require/verifyCA/verifyFull TLS 且绝不回退明文。
@Suite("Redis TLS 传输安全")
struct RedisTransportSecurityTests {

    // MARK: - 计划映射

    @Test("disable 与未设置使用明文（回归 #273）")
    func disableAndNilUsePlaintext() {
        for option in [ConnectionSSLOption?.none, .some(.disable)] {
            let plan = RedisTransportPlan.make(sslOption: option)
            #expect(!plan.usesTLS)
            #expect(!plan.allowsPlaintextFallback)
        }
    }

    @Test("require 启用 TLS、不校验证书、绝不回退明文（回归 #273）")
    func requireEnablesTLSWithoutFallback() {
        let plan = RedisTransportPlan.make(sslOption: .require)
        #expect(plan.usesTLS)
        #expect(!plan.allowsPlaintextFallback)
        #expect(plan.verification == .none)
    }

    @Test("verify-ca 启用 TLS、仅校验 CA、绝不回退明文（回归 #273）")
    func verifyCAEnablesTLSWithCAOnlyVerification() {
        let plan = RedisTransportPlan.make(sslOption: .verifyCA)
        #expect(plan.usesTLS)
        #expect(!plan.allowsPlaintextFallback)
        #expect(plan.verification == .caOnly)
    }

    @Test("verify-full 启用 TLS、校验 CA+主机名、绝不回退明文（回归 #273）")
    func verifyFullEnablesTLSWithFullVerification() {
        let plan = RedisTransportPlan.make(sslOption: .verifyFull)
        #expect(plan.usesTLS)
        #expect(!plan.allowsPlaintextFallback)
        #expect(plan.verification == .full)
    }

    @Test("prefer 启用 TLS、不校验证书、允许回退明文（回归 #273）")
    func preferEnablesTLSWithPlaintextFallback() {
        let plan = RedisTransportPlan.make(sslOption: .prefer)
        #expect(plan.usesTLS)
        #expect(plan.allowsPlaintextFallback)
        #expect(plan.verification == .none)
    }

    // MARK: - NWParameters 构造

    @Test("TLS 计划构造的 NWParameters 含 TLS 协议，不得是明文（回归 #273）")
    func tlsPlansProduceTLSParameters() {
        for option in [ConnectionSSLOption.prefer, .require, .verifyCA, .verifyFull] {
            let plan = RedisTransportPlan.make(sslOption: option)
            let parameters = RedisTransportSecurity.makeParameters(plan: plan, host: "db.example.com")
            #expect(parameters.defaultProtocolStack.applicationProtocols.contains { $0 is NWProtocolTLS.Options })
        }
    }

    @Test("明文计划构造的 NWParameters 不含 TLS 协议（回归 #273）")
    func plaintextPlansProduceTCPParameters() {
        for option in [ConnectionSSLOption?.none, .some(.disable)] {
            let plan = RedisTransportPlan.make(sslOption: option)
            let parameters = RedisTransportSecurity.makeParameters(plan: plan, host: "db.example.com")
            #expect(!parameters.defaultProtocolStack.applicationProtocols.contains { $0 is NWProtocolTLS.Options })
        }
    }
}