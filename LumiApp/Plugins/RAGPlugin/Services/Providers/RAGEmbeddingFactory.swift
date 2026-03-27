import Foundation

/// 向量化工厂类
/// 负责创建和配置不同的向量化提供者
enum RAGEmbeddingFactory {
    
    /// 创建默认的向量化提供者
    /// - Returns: 向量化提供者实例
    static func makeProvider() -> RAGEmbeddingProvider {
        // 固定使用 App 内原生 embedding
        // 若原生向量不可用，AppleNativeEmbeddingProvider 内部会自动回退到 hash
        return AppleNativeEmbeddingProvider(dimension: 384)
    }
    
    /// 创建哈希向量化提供者（备用方案）
    /// - Parameter dimension: 向量维度
    /// - Returns: 哈希向量化提供者实例
    static func makeHashProvider(dimension: Int = 256) -> RAGEmbeddingProvider {
        return HashEmbeddingProvider(dimension: dimension)
    }
    
    /// 创建 Apple 原生向量化提供者
    /// - Parameter dimension: 向量维度
    /// - Returns: Apple 原生向量化提供者实例
    static func makeAppleNativeProvider(dimension: Int = 384) -> RAGEmbeddingProvider {
        return AppleNativeEmbeddingProvider(dimension: dimension)
    }
}
