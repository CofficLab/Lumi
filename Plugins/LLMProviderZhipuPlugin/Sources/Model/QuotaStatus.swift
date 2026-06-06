import Foundation

/// 智谱配额状态
enum QuotaStatus {
    case loading
    case success(QuotaData)
    case authError
    case unavailable
}
