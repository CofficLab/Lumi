import Foundation
import HttpKit

/// HTTP 错误解析工具
public enum LumiLLMHTTPErrorParsing {

    /// 从错误中提取 HTTP 状态码
    public static func statusCode(from error: Error) -> Int? {
        if let httpError = error as? HTTPClientError {
            switch httpError {
            case .httpError(let statusCode, _):
                return statusCode
            default:
                return nil
            }
        }
        if let urlError = error as? URLError {
            return urlError.errorCode
        }
        if let nsError = error as NSError?, nsError.domain == NSURLErrorDomain {
            return nsError.code
        }
        return nil
    }
}