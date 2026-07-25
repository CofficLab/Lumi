import Foundation

/// MiniMax Token Plan 配额状态
enum TokenPlanStatus {
    case loading
    case success(TokenPlanData)
    case authError
    case unavailable
}

/// MiniMax Token Plan API 响应数据
struct TokenPlanData {
    let modelName: String
    let totalCount: Int
    let remains: Int

    /// 格式化状态栏显示文本
    var statusText: String {
        let percentage = totalCount > 0 ? Double(remains) / Double(totalCount) * 100 : 0
        let shortModel = modelName.split(separator: "-").first.map(String.init) ?? modelName
        return String(format: "%.0f%% %@ %d/%d", percentage, shortModel, remains, totalCount)
    }

    /// 剩余百分比
    var remainingPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(remains) / Double(totalCount) * 100
    }
}
