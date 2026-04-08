import Foundation

/// Gemma 4 系列模型定义
///
/// Google 最新开源的多模态大语言模型系列
public enum Gemma4Models {
    
    /// 所有 Gemma 4 模型列表
    public static let all: [LocalModelInfo] = [
        // Gemma 4 E2B 系列 - 5B 参数
        LocalModelInfo(
            id: "mlx-community/gemma-4-E2B-it-4bit",
            displayName: "Gemma 4 E2B Instruct",
            description: "Google 轻量级模型，适合低内存设备",
            size: "~1.5 GB",
            minRAM: 8,
            expectedBytes: 1_500_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 20,
            series: "Gemma 4 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/gemma-4-E2B-4bit",
            displayName: "Gemma 4 E2B",
            description: "Google 轻量级基础模型",
            size: "~1.5 GB",
            minRAM: 8,
            expectedBytes: 1_500_000_000,
            supportsVision: false,
            supportsTools: false,
            priority: 21,
            series: "Gemma 4 系列"
        ),
        
        // Gemma 4 E4B 系列 - 8B 参数
        LocalModelInfo(
            id: "mlx-community/gemma-4-E4B-it-4bit",
            displayName: "Gemma 4 E4B Instruct",
            description: "Google 轻量级指令模型",
            size: "~2.5 GB",
            minRAM: 8,
            expectedBytes: 2_500_000_000,
            supportsVision: false,
            supportsTools: true,
            priority: 22,
            series: "Gemma 4 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/gemma-4-E4B-4bit",
            displayName: "Gemma 4 E4B",
            description: "Google 轻量级基础模型",
            size: "~2.5 GB",
            minRAM: 8,
            expectedBytes: 2_500_000_000,
            supportsVision: false,
            supportsTools: false,
            priority: 23,
            series: "Gemma 4 系列"
        ),
        
        // Gemma 4 26B-A4B 系列 - 27B 参数
        LocalModelInfo(
            id: "mlx-community/gemma-4-26B-A4B-it-4bit",
            displayName: "Gemma 4 26B-A4B Instruct",
            description: "Google 中端指令模型，支持多模态",
            size: "~16 GB",
            minRAM: 32,
            expectedBytes: 16_000_000_000,
            supportsVision: true,
            supportsTools: true,
            priority: 24,
            series: "Gemma 4 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/gemma-4-26B-A4B-4bit",
            displayName: "Gemma 4 26B-A4B",
            description: "Google 中端基础模型，支持多模态",
            size: "~16 GB",
            minRAM: 32,
            expectedBytes: 16_000_000_000,
            supportsVision: true,
            supportsTools: false,
            priority: 25,
            series: "Gemma 4 系列"
        ),
        
        // Gemma 4 31B 系列 - 31B 参数
        LocalModelInfo(
            id: "mlx-community/gemma-4-31B-it-4bit",
            displayName: "Gemma 4 31B Instruct",
            description: "Google 大型指令模型，强大的多模态能力",
            size: "~19 GB",
            minRAM: 32,
            expectedBytes: 19_000_000_000,
            supportsVision: true,
            supportsTools: true,
            priority: 26,
            series: "Gemma 4 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/gemma-4-31B-4bit",
            displayName: "Gemma 4 31B",
            description: "Google 大型基础模型，强大的多模态能力",
            size: "~19 GB",
            minRAM: 32,
            expectedBytes: 19_000_000_000,
            supportsVision: true,
            supportsTools: false,
            priority: 27,
            series: "Gemma 4 系列"
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
