import Foundation
import os

/// RAG 检索结果
struct RAGSearchResult {
    let content: String
    let source: String
    let score: Float
}

/// RAG 响应
struct RAGResponse {
    let query: String
    let results: [RAGSearchResult]
    
    var hasResults: Bool { !results.isEmpty }
}

/// RAG 核心服务
///
/// 职责：检索增强生成的核心逻辑
///
/// ## 工作流程
/// 1. 索引：把文档变成向量存起来
/// 2. 检索：用户提问时，搜索相关文档
///
actor RAGService {
    
    // MARK: - 属性
    
    /// 是否已初始化
    private(set) var isInitialized: Bool = false
    
    /// 模拟：存储的文档向量
    private var documentVectors: [(content: String, source: String, vector: [Float])] = []
    
    // MARK: - 初始化
    
    init() {
        AppLogger.rag.info("🦞 RAG 服务已创建")
    }
    
    // MARK: - 初始化
    
    /// 初始化服务
    func initialize() async throws {
        guard !isInitialized else { return }
        
        AppLogger.rag.info("📦 RAG 服务初始化中...")
        
        // 模拟：加载 Embedding 模型
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // 模拟：初始化向量数据库
        try await Task.sleep(nanoseconds: 50_000_000)
        
        isInitialized = true
        AppLogger.rag.info("✅ RAG 服务初始化完成")
    }
    
    // MARK: - 索引
    
    /// 索引项目
    func indexProject(at path: String) async throws {
        guard isInitialized else { throw RAGError.notInitialized }
        
        AppLogger.rag.info("📚 索引项目: \(path)")
        
        // 清除旧数据
        self.documentVectors.removeAll()
        
        // 模拟：生成一些测试文档
        let mockDocs = self.createMockDocuments()
        
        // 模拟：生成向量并存储
        for doc in mockDocs {
            let vector = self.simulateEmbedding(doc.content)
            self.documentVectors.append((doc.content, doc.source, vector))
        }
        
        AppLogger.rag.info("✅ 已索引 \(self.documentVectors.count) 个文档片段")
    }
    
    // MARK: - 检索
    
    /// 检索相关文档
    func retrieve(query: String, topK: Int = 3) async throws -> RAGResponse {
        guard isInitialized else { throw RAGError.notInitialized }
        
        AppLogger.rag.info("🔍 检索: \"\(query)\"")
        
        // 1. 问题转向量
        let queryVector = self.simulateEmbedding(query)
        
        // 2. 计算相似度
        var results: [(content: String, source: String, score: Float)] = []
        
        for doc in self.documentVectors {
            let score = self.cosineSimilarity(queryVector, doc.vector)
            results.append((doc.content, doc.source, score))
        }
        
        // 3. 排序并取 topK
        results.sort { $0.score > $1.score }
        let topResults = results.prefix(topK).map {
            RAGSearchResult(content: $0.content, source: $0.source, score: $0.score)
        }
        
        AppLogger.rag.info("✅ 找到 \(topResults.count) 个相关文档")
        
        return RAGResponse(query: query, results: topResults)
    }
    
    // MARK: - 模拟实现
    
    /// 模拟：创建测试文档
    private func createMockDocuments() -> [(content: String, source: String)] {
        return [
            (
                "class LoginViewController: UIViewController {\n    // 登录界面控制器\n    func handleLogin() { }\n}",
                "LoginViewController.swift"
            ),
            (
                "class AuthManager {\n    // 认证管理器\n    func login() async throws { }\n    func logout() { }\n}",
                "AuthManager.swift"
            ),
            (
                "class APIClient {\n    // 网络请求客户端\n    func request<T>() async throws -> T { }\n}",
                "APIClient.swift"
            ),
            (
                "# 项目配置\n\n## API 配置\n- 基础 URL: https://api.example.com\n- 超时: 30秒",
                "README.md"
            ),
            (
                "# 用户管理\n\n## 功能\n- 用户注册\n- 用户登录\n- 密码重置",
                "Docs/UserManagement.md"
            )
        ]
    }
    
    /// 模拟：生成向量
    private func simulateEmbedding(_ text: String) -> [Float] {
        // 使用文本哈希生成伪向量
        var vector = [Float](repeating: 0, count: 384)
        let hash = Float(abs(text.hashValue % 1000)) / 1000.0
        
        for i in 0..<384 {
            vector[i] = (hash + Float(i) / 384.0) * 0.5
        }
        
        // 归一化
        let magnitude = sqrt(vector.map { $0 * $0 }.reduce(0, +))
        if magnitude > 0 {
            vector = vector.map { $0 / magnitude }
        }
        
        return vector
    }
    
    /// 计算余弦相似度
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        
        let dot = zip(a, b).map { $0 * $1 }.reduce(0, +)
        let magA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }
}

// MARK: - 错误

enum RAGError: LocalizedError {
    case notInitialized
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "RAG 服务未初始化"
        }
    }
}

// MARK: - 日志

extension AppLogger {
    static let rag = Logger(subsystem: "com.coffic.lumi", category: "RAG")
}