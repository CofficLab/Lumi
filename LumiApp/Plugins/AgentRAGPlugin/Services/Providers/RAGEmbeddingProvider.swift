import Foundation

/// 向量化提供者协议
protocol RAGEmbeddingProvider {
    /// 模型标识符
    var modelID: String { get }
    
    /// 模型版本
    var modelVersion: String { get }
    
    /// 向量维度
    var dimension: Int { get }

    /// 将单条文本转换为向量
    /// - Parameter text: 输入文本
    /// - Returns: 向量数组
    func embed(_ text: String) throws -> [Float]
    
    /// 批量将文本转换为向量
    /// - Parameter texts: 输入文本数组
    /// - Returns: 向量数组
    func embedBatch(_ texts: [String]) throws -> [[Float]]
}

extension RAGEmbeddingProvider {
    /// 模型标识符（包含版本）
    var modelIdentifierWithVersion: String {
        "\(modelID)@\(modelVersion)"
    }

    /// 默认批量实现（逐个处理）
    func embedBatch(_ texts: [String]) throws -> [[Float]] {
        try texts.map(embed)
    }
}
