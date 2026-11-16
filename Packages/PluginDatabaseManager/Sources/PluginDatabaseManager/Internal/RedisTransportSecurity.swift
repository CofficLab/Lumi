import Foundation
import Network
import Security

/// Redis 传输层安全计划：把 ``ConnectionSSLOption`` 映射为 Network.framework 可执行的决策。
///
/// Redis 驱动走 `NWConnection`（而非 MySQL/PostgreSQL 的 NIOSSL），无法复用
/// ``ConnectionSSLOption/makeTLSConfiguration()``，但校验强度必须与之一致（#273）：
/// - disable / nil：明文；
/// - prefer：TLS，不校验证书，失败可回退明文；
/// - require：TLS，不校验证书，**绝不回退明文**；
/// - verifyCA：TLS，校验 CA、不校验主机名，绝不回退；
/// - verifyFull：TLS，校验 CA + 主机名，绝不回退。
///
/// 此前驱动恒用 `.tcp`，即便用户选择 TLS 也明文发送 AUTH，泄露凭据。
struct RedisTransportPlan: Equatable, Sendable {
    enum Verification: Equatable, Sendable {
        /// 不校验证书（prefer / require，自签证书可用）。
        case none
        /// 校验 CA，不校验主机名（verifyCA）。
        case caOnly
        /// 校验 CA + 主机名（verifyFull，最严格）。
        case full
    }

    let usesTLS: Bool
    let allowsPlaintextFallback: Bool
    let verification: Verification

    static func make(sslOption: ConnectionSSLOption?) -> RedisTransportPlan {
        switch sslOption {
        case nil, .disable:
            return RedisTransportPlan(usesTLS: false, allowsPlaintextFallback: false, verification: .none)
        case .prefer:
            return RedisTransportPlan(usesTLS: true, allowsPlaintextFallback: true, verification: .none)
        case .require:
            return RedisTransportPlan(usesTLS: true, allowsPlaintextFallback: false, verification: .none)
        case .verifyCA:
            return RedisTransportPlan(usesTLS: true, allowsPlaintextFallback: false, verification: .caOnly)
        case .verifyFull:
            return RedisTransportPlan(usesTLS: true, allowsPlaintextFallback: false, verification: .full)
        }
    }
}

enum RedisTransportSecurity {
    /// 按计划构造 `NWParameters`。明文计划返回 `.tcp`；TLS 计划按校验强度设置 verify block。
    static func makeParameters(plan: RedisTransportPlan, host: String) -> NWParameters {
        guard plan.usesTLS else { return .tcp }

        let tlsOptions = NWProtocolTLS.Options()
        let securityOptions = tlsOptions.securityProtocolOptions
        let verifyQueue = DispatchQueue(label: "databasekit.redis.tls.verify")

        switch plan.verification {
        case .none:
            // 接受任意证书（含自签），对齐 NIOSSL 的 certificateVerification = .none。
            sec_protocol_options_set_verify_block(securityOptions, { _, _, completionHandler in
                completionHandler(true)
            }, verifyQueue)
        case .caOnly:
            // 只评估证书链（CA），用不带主机名的 SSL 策略，对齐 .noHostnameVerification。
            sec_protocol_options_set_verify_block(securityOptions, { _, trust, completionHandler in
                let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
                let policy = SecPolicyCreateSSL(true, nil)
                SecTrustSetPolicies(secTrust, [policy] as CFArray)
                var error: CFError?
                completionHandler(SecTrustEvaluateWithError(secTrust, &error))
            }, verifyQueue)
        case .full:
            // Network.framework 默认即校验 CA + 主机名（peer name 取自 NWConnection 的 host）。
            break
        }

        return NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
    }
}