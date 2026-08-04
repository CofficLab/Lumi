import Foundation
import LumiKernel

/// Microsoft 模型系列定义
///
/// 微软开源的 Phi 系列小模型，质量高、体积小
public enum MicrosoftModels {

    /// 所有 Microsoft 模型列表
    public static let all: [LocalModelInfo] = [
        LocalModelInfo(
            id: "mlx-community/Phi-4-mini-instruct-4bit",
            displayName: LumiPluginLocalization.string("Phi-4 mini", bundle: .module),
            description: LumiPluginLocalization.string("微软轻量模型，小体积高质量", bundle: .module),
            size: "~2.2 GB",
            minRAM: 8,
            expectedBytes: 2_180_067_259,
            supportsVision: false,
            supportsTools: true,
            priority: 50,
            series: "Microsoft 系列"
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
