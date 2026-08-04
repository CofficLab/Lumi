import Foundation
import LumiKernel

/// Mistral 系列模型定义
///
/// 轻量高效的大语言模型系列
public enum MistralModels {
    
    /// 所有 Mistral 模型列表
    public static let all: [LocalModelInfo] = [
        LocalModelInfo(
            id: "mlx-community/Mistral-Nemo-Instruct-2407-4bit",
            displayName: LumiPluginLocalization.string("Mistral Nemo 12B", bundle: .module),
            description: LumiPluginLocalization.string("轻量高效，适合日常使用", bundle: .module),
            size: "~6.9 GB",
            minRAM: 16,
            expectedBytes: 6_905_203_123,
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
