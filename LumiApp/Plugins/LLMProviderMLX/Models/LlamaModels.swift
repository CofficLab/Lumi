import Foundation

/// Llama 系列模型定义
///
/// Meta 开源大语言模型系列，通用能力强
public enum LlamaModels {
    
    /// 所有 Llama 模型列表
    public static let all: [LocalModelInfo] = [
        LocalModelInfo(
            id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            displayName: "Llama 3.2 3B",
            description: "超轻量，适合低配置设备",
            size: "~2 GB",
            minRAM: 8,
            expectedBytes: 2_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 5,
            series: "Llama 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Llama-3.3-70B-Instruct-4bit",
            displayName: "Llama 3.3 70B",
            description: "最强开源模型，需要高配置",
            size: "~40 GB",
            minRAM: 64,
            expectedBytes: 40_000_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 6,
            series: "Llama 系列"
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
