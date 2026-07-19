import Foundation
import LumiKernel

/// 代码模型系列定义
///
/// 擅长编程与代码补全的开源模型系列
public enum CoderModels {

    /// 所有代码模型列表
    public static let all: [LocalModelInfo] = [
        LocalModelInfo(
            id: "mlx-community/Qwen2.5-Coder-3B-Instruct-4bit",
            displayName: LumiPluginLocalization.string("Qwen2.5 Coder 3B", bundle: .module),
            description: LumiPluginLocalization.string("轻量代码模型，适合代码补全", bundle: .module),
            size: "~1.7 GB",
            minRAM: 8,
            expectedBytes: 1_747_851_791,
            supportsVision: false,
            supportsTools: true,
            priority: 30,
            series: "代码 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit",
            displayName: LumiPluginLocalization.string("Qwen2.5 Coder 7B", bundle: .module),
            description: LumiPluginLocalization.string("平衡的代码模型，兼顾速度与能力", bundle: .module),
            size: "~4.3 GB",
            minRAM: 8,
            expectedBytes: 4_295_890_004,
            supportsVision: false,
            supportsTools: true,
            priority: 31,
            series: "代码 系列"
        ),
        LocalModelInfo(
            id: "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit",
            displayName: LumiPluginLocalization.string("Qwen3 Coder 30B", bundle: .module),
            description: LumiPluginLocalization.string("MoE 代码模型，强大的编程能力，需要高配置", bundle: .module),
            size: "~17.2 GB",
            minRAM: 32,
            expectedBytes: 17_197_118_924,
            supportsVision: false,
            supportsTools: true,
            priority: 32,
            series: "代码 系列"
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
