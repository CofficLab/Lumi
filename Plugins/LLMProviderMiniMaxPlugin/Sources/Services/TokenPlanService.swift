import Foundation
import HttpKit
import LLMKit
import LumiKernel

/// MiniMax Token Plan 配额服务
enum TokenPlanService {
    /// 请求超时时间（秒）
    private static let timeout: TimeInterval = 5.0
    
    /// 获取 Token Plan 配额
    static func fetchTokenPlan() async -> TokenPlanStatus {
        let tokenPlanURL = "https://www.minimaxi.com/v1/token_plan/remains"
        
        // 从 LumiAPIKeyTools 获取 API Key
        let apiKey = LumiAPIKeyTools.get(storageKey: MiniMaxTokenPlanProvider.info._apiKeyStorageKey)
        guard !apiKey.isEmpty else {
            return .authError
        }
        
        guard let url = URL(string: tokenPlanURL) else {
            return .unavailable
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = timeout
        
        let client = HTTPClient(timeoutIntervalForRequest: timeout, timeoutIntervalForResource: timeout)
        
        do {
            let data = try await client.sendRequest(request: request)
            
            // 解析 JSON
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .unavailable
            }
            
            // 检查状态码
            if let statusCode = json["status_code"] as? Int, statusCode != 0 {
                if statusCode == 1001 || statusCode == 1002 {
                    return .authError
                }
                return .unavailable
            }
            
            // 提取配额数据
            guard let dataDict = json["data"] as? [String: Any],
                  let tokenPlans = dataDict["token_plans"] as? [[String: Any]] else {
                return .unavailable
            }
            
            // 解析模型配额列表
            let plans = tokenPlans.compactMap { plan -> TokenPlanData? in
                guard let model = plan["model"] as? String,
                      let total = plan["total"] as? Int,
                      let remains = plan["remains"] as? Int else {
                    return nil
                }
                
                return TokenPlanData(
                    modelName: model,
                    totalCount: total,
                    remains: remains
                )
            }
            
            guard !plans.isEmpty else {
                return .unavailable
            }
            
            // 选择剩余配额最多的计划
            let bestPlan = plans.max { $0.remains < $1.remains }!
            return .success(bestPlan)
            
        } catch let error as HTTPClientError {
            if case let .httpError(statusCode, _) = error {
                if statusCode == 401 || statusCode == 403 {
                    return .authError
                }
            }
            return .unavailable
        } catch {
            return .unavailable
        }
    }
}