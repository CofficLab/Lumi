import Foundation

/// 模型偏好数据模型
struct ModelPreference: Codable {
    /// 供应商名称（如 "OpenAI", "Anthropic"）
    let provider: String

    /// 模型名称（如 "gpt-4", "claude-3-opus"）
    let model: String

    /// 保存时间戳
    let timestamp: TimeInterval

    init(provider: String, model: String) {
        self.provider = provider
        self.model = model
        self.timestamp = Date().timeIntervalSince1970
    }

    /// 转换为字典
    func toDictionary() -> [String: Any] {
        [
            "provider": provider,
            "model": model,
            "timestamp": timestamp
        ]
    }

    /// 从字典初始化
    static func fromDictionary(_ dict: [String: Any]) -> ModelPreference? {
        guard let provider = dict["provider"] as? String,
              let model = dict["model"] as? String,
              let timestamp = dict["timestamp"] as? TimeInterval else {
            return nil
        }
        return ModelPreference(provider: provider, model: model)
    }
}

/// 模型偏好键枚举
enum ModelPreferenceKey: String {
    case provider
    case model
    case timestamp
}