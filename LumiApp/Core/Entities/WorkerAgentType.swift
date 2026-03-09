import Foundation

/// Worker 类型定义
///
/// 由 Manager 选择后用于创建专长 Worker。
enum WorkerAgentType: String, Codable, Sendable, CaseIterable {
    /// 代码分析、修改、重构
    case codeExpert = "code_expert"

    /// 文档编写、注释整理
    case documentExpert = "document_expert"

    /// 测试编写、质量检查
    case testExpert = "test_expert"

    /// 架构设计、审查优化
    case architect = "architect"
}
