import Foundation

/// HTTP 错误解析工具（纯标准库，无项目依赖）。
///
/// 从 `URLError` / `NSError` 中提取 HTTP 状态码。
/// 传输层错误可通过实现 `LLMHTTPErrorProviding` 协议携带状态码。
public enum VendorLLMHTTPErrorParsing {

    /// 从错误中提取 HTTP 状态码。
    public static func statusCode(from error: Error) -> Int? {
        // 1. 传输层自定义错误协议
        if let httpError = error as? LLMHTTPErrorProviding {
            return httpError.httpStatusCode
        }
        // 2. NSError userInfo 中的 statusCode
        if let nsError = error as NSError?,
           let code = nsError.userInfo["statusCode"] as? Int {
            return code
        }
        return nil
    }
}

/// 传输层错误可实现此协议以携带 HTTP 状态码。
///
/// 各 Provider 的传输层（URLSession / 自定义 HTTP 客户端）将响应错误
/// 包装为符合此协议的类型后，协议适配器的重试判断即可自动提取状态码。
public protocol LLMHTTPErrorProviding: Error {
    var httpStatusCode: Int? { get }
}
