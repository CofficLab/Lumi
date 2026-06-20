import Foundation

/// 标记为"不可重试"的错误协议。
///
/// 遵循此协议的错误代表**确定性失败**——无论如何重试结果都一样，
/// 例如 API Key 未配置、供应商未找到、Base URL 无效等。
///
/// `SendPipeline` 的重试循环会通过 `NonRetryableErrorChecker.isNonRetryable(_:)`
/// 检查错误是否不可重试，遇到不可重试错误时直接跳出循环。
public protocol NonRetryableError: Error {}

// MARK: -

/// 提供 `isNonRetryable` 属性的错误协议。
///
/// 对于只有部分 case 不可重试的 enum（如 `LumiLLMProviderSupportError`），
/// 实现此协议来精确控制哪些错误不应重试。
public protocol NonRetryableErrorProviding: Error {
    var isNonRetryable: Bool { get }
}

// MARK: -

/// 运行时检查工具：判断一个错误是否属于"不可重试"类别。
public enum NonRetryableErrorChecker {
    /// 检查错误是否不可重试。
    public static func isNonRetryable(_ error: Error) -> Bool {
        // 方式 1：直接遵循 NonRetryableError 协议（整个类型都不可重试）
        if error is NonRetryableError {
            return true
        }

        // 方式 2：遵循 NonRetryableErrorProviding 协议，按 case 判断
        if let provider = error as? NonRetryableErrorProviding {
            return provider.isNonRetryable
        }

        return false
    }
}
