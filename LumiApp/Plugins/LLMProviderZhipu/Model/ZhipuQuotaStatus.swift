import Foundation

/// 智谱配额状态
enum ZhipuQuotaStatus {
    case loading
    case success(ZhipuQuotaData)
    case authError
    case unavailable
}
