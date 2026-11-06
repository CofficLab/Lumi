import Foundation

// MARK: - Auth Scheme

/// 鉴权方案。
///
/// 服务端按顺序尝试每个方案，任一方案通过即放行。当前内置：
/// - `bearer`：`Authorization: Bearer <token>`
/// - `apiKey`：`X-API-Key: <key>`
///
/// 方案本身只描述「凭证从哪儿取、怎么比对」，不含任何具体凭证值。
public enum WebAuthScheme: String, Sendable, CaseIterable, Codable {
    /// `Authorization: Bearer <token>`。也兼容不带 `Bearer ` 前缀的裸 token。
    case bearer
    /// `X-API-Key: <key>` 请求头。
    case apiKey

    /// 从请求中提取该方案对应的原始凭证字符串。
    ///
    /// - Parameter headers: 请求头，key 已归一化为小写。
    /// - Returns: 凭证字符串；不存在时返回 `nil`。
    public func credential(in headers: [String: String]) -> String? {
        switch self {
        case .bearer:
            guard let raw = headers["authorization"]?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
                return nil
            }
            // 兼容裸 token：部分调用方不会加 `Bearer ` 前缀。
            if raw.lowercased().hasPrefix("bearer ") {
                return String(raw.dropFirst("bearer ".count)).trimmingCharacters(in: .whitespaces)
            }
            return raw
        case .apiKey:
            guard let raw = headers["x-api-key"]?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
                return nil
            }
            return raw
        }
    }
}

// MARK: - Auth Policy

/// 鉴权策略。
///
/// 描述「哪些请求需要凭证」以及「用哪种方案校验」。服务端据此在派发前
/// 完成校验，插件处理器不需要各自重复实现鉴权。
///
/// - Note: `verifier` 不参与相等性比较——两个闭包无法有意义地比较。
///   相等性只看「启用了哪些方案」与「是否允许匿名」，这正是策略的语义部分。
public struct WebAuthPolicy: Sendable {
    /// 允许的鉴权方案，按优先级排列。
    public let schemes: [WebAuthScheme]

    /// 是否允许匿名访问（不携带任何凭证）。
    ///
    /// 为 `true` 时，携带**错误**凭证的请求仍会被拒绝——「不要求凭证」不等于
    /// 「忽略错误凭证」，否则拼错的 token 会让人误以为鉴权已通过。
    public let allowsAnonymous: Bool

    /// 凭证校验闭包。由服务实现注入（比对具体 token / key）。
    ///
    /// 未设置时**任何凭证都判定为不通过**——「配置了鉴权但没给校验器」应当
    /// 表现为拒绝，而不是静默放行。
    var verifier: (@Sendable (WebAuthScheme, String) -> Bool)?

    /// 构造策略。
    ///
    /// - Parameters:
    ///   - schemes: 允许的鉴权方案，默认 `[.bearer]`。
    ///   - allowsAnonymous: 是否允许匿名访问，默认 `false`。
    public init(schemes: [WebAuthScheme] = [.bearer], allowsAnonymous: Bool = false) {
        self.schemes = schemes
        self.allowsAnonymous = allowsAnonymous
    }

    /// 强制鉴权（Bearer + API Key 均可）。
    public static let required = WebAuthPolicy()

    /// 允许匿名访问，但仍接受合法凭证。
    public static let optional = WebAuthPolicy(allowsAnonymous: true)

    /// 不做鉴权。
    ///
    /// 仅适用于服务绑定在回环地址、且调用方完全可信的场景。
    public static let none = WebAuthPolicy(schemes: [], allowsAnonymous: true)

    /// 校验请求是否通过。
    ///
    /// - Parameter headers: 请求头，key 已归一化为小写。
    /// - Returns: 通过返回 `nil`；否则返回应当返回给调用方的错误。
    public func validate(headers: [String: String]) -> WebAPIError? {
        // 收集调用方实际提供的凭证（按方案顺序）。
        var provided: [WebAuthScheme: String] = [:]
        for scheme in schemes {
            if let credential = scheme.credential(in: headers), !credential.isEmpty {
                provided[scheme] = credential
            }
        }

        // 一个凭证都没提供：按是否允许匿名处理。
        if provided.isEmpty {
            return allowsAnonymous ? nil : .unauthorized()
        }

        // 提供了凭证：必须与某个允许的方案匹配，否则一律拒绝。
        for scheme in schemes {
            guard let credential = provided[scheme] else { continue }
            if verifier?(scheme, credential) == true {
                return nil
            }
        }
        return .unauthorized()
    }

    /// 注入凭证校验器。
    ///
    /// - Parameter verifier: 校验闭包。返回 `true` 表示凭证有效。
    /// - Returns: 配置了校验器的策略副本。
    public func withVerifier(_ verifier: @escaping @Sendable (WebAuthScheme, String) -> Bool) -> WebAuthPolicy {
        var copy = self
        copy.verifier = verifier
        return copy
    }

    /// 令牌相等性比较。
    ///
    /// 逐字节比较而非 `==`，避免因短路比较而泄漏前缀信息（时序侧信道）。
    static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        guard left.count == right.count else { return false }
        var difference: UInt8 = 0
        for index in left.indices {
            difference |= left[index] ^ right[index]
        }
        return difference == 0
    }
}

extension WebAuthPolicy: Equatable {
    /// 只比较策略的语义部分（方案集合与匿名策略），忽略校验器闭包。
    public static func == (lhs: WebAuthPolicy, rhs: WebAuthPolicy) -> Bool {
        lhs.schemes == rhs.schemes && lhs.allowsAnonymous == rhs.allowsAnonymous
    }
}

// MARK: - Credentials

/// 一组服务端认可的凭证。
///
/// 支持「同一个 token 用多种方案提交」以及「多把 key 轮换」两种常见需求。
/// 存储在内存中，不落盘。
public struct WebCredentialStore: Sendable {
    /// 各方案下认可的凭证集合。
    private var credentials: [WebAuthScheme: Set<String>]

    /// 创建凭证存储。
    ///
    /// - Parameter credentials: 方案到凭证集合的映射。
    public init(credentials: [WebAuthScheme: Set<String>] = [:]) {
        self.credentials = credentials
    }

    /// 是否没有任何凭证（此时鉴权策略应允许匿名）。
    public var isEmpty: Bool {
        credentials.values.allSatisfy(\.isEmpty)
    }

    /// 添加一个凭证。
    public mutating func add(_ value: String, for scheme: WebAuthScheme) {
        guard !value.isEmpty else { return }
        credentials[scheme, default: []].insert(value)
    }

    /// 移除一个凭证。
    public mutating func remove(_ value: String, for scheme: WebAuthScheme) {
        credentials[scheme]?.remove(value)
    }

    /// 移除某个方案下的全部凭证。
    public mutating func removeAll(for scheme: WebAuthScheme) {
        credentials[scheme] = []
    }

    /// 校验凭证是否有效。
    public func validate(_ value: String, for scheme: WebAuthScheme) -> Bool {
        guard let accepted = credentials[scheme] else { return false }
        // 遍历全部候选并全部比较，避免通过「首个不匹配即返回」泄漏集合信息。
        var matched = false
        for candidate in accepted {
            if WebAuthPolicy.constantTimeEquals(candidate, value) {
                matched = true
            }
        }
        return matched
    }

    /// 生成配套的鉴权策略。
    ///
    /// - Parameters:
    ///   - schemes: 启用的方案；默认 `[.bearer]`。
    ///   - allowsAnonymous: 是否允许匿名访问，默认 `false`。
    /// - Returns: 已注入校验器的策略。
    public func policy(schemes: [WebAuthScheme] = [.bearer], allowsAnonymous: Bool = false) -> WebAuthPolicy {
        let store = self
        return WebAuthPolicy(schemes: schemes, allowsAnonymous: allowsAnonymous)
            .withVerifier { scheme, credential in
                store.validate(credential, for: scheme)
            }
    }
}
