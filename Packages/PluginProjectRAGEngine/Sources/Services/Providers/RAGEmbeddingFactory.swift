import Foundation

/// 向量化工厂类
/// 负责创建和配置不同的向量化提供者
public enum RAGEmbeddingFactory {
    /// 创建默认的向量化提供者
    /// - Returns: 向量化提供者实例
    public static func makeProvider() -> RAGEmbeddingProvider {
        // 固定使用 App 内原生 embedding
        // 若原生向量不可用，AppleNativeEmbeddingProvider 内部会自动回退到 hash
        return AppleNativeEmbeddingProvider(dimension: 384)
    }

    /// 创建哈希向量化提供者（用于测试和开发）
    /// - Parameter dimension: 向量维度
    /// - Returns: 伪向量化提供者实例
    public static func makeHashProvider(dimension: Int = 256) -> RAGEmbeddingProvider {
        return MockEmbeddingProvider(dimension: dimension)
    }

    /// 创建 Apple 原生向量化提供者
    /// - Parameter dimension: 向量维度
    /// - Returns: Apple 原生向量化提供者实例
    public static func makeAppleNativeProvider(dimension: Int = 384) -> RAGEmbeddingProvider {
        return AppleNativeEmbeddingProvider(dimension: dimension)
    }
}
