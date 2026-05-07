import Foundation

/// Mistral 系列模型定义
///
/// 轻量高效的大语言模型系列
public enum MistralModels {
    
    /// 所有 Mistral 模型列表
    public static let all: [LocalModelInfo] = [
        LocalModelInfo(
            id: "mlx-community/Mistral-Nemo-12B-Instruct-4bit",
            displayName: "Mistral Nemo 12B",
            description: "轻量高效，适合日常使用",
            size: "~7 GB",
            minRAM: 16,
            expectedBytes: 7_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 4,
            series: "Mistral 系列"
        ),
    ]
    
    /// 获取支持视觉的模型
    public static var visionModels: [LocalModelInfo] { all.filter { $0.supportsVision } }
    
    /// 获取支持工具调用的模型
    public static var toolModels: [LocalModelInfo] { all.filter { $0.supportsTools } }
    
    /// 根据 ID 查找模型
    public static func model(id: String) -> LocalModelInfo? {
        all.first { $0.id == id }
    }
    
    /// 根据内存要求过滤可用模型
    public static func availableModels(for systemRAM: Int) -> [LocalModelInfo] {
        all.filter { $0.minRAM <= systemRAM }
    }
}
