import Foundation
import LLMKit

/// LLM 深度问题分析器
///
/// 使用 LLM 对项目代码进行深度分析，发现潜在 bug、安全风险、性能问题等。
/// LLM 服务通过 Root 视图的 @EnvironmentObject 获取，传递给本分析器。
actor DeepIssueAnalyzer: SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose = false

    static let shared = DeepIssueAnalyzer()

    // MARK: - State

    private var llmService: LLMService?
    private var configProvider: SuperLLMConfigProvider?

    // MARK: - Public API

    /// 配置 LLM 服务（由 Root 视图调用）
    ///
    /// 通过 @EnvironmentObject 获取 AppLLMVM 后，调用此方法传递 LLM 服务引用。
    func configure(llmService: LLMService, configProvider: SuperLLMConfigProvider) {
        self.llmService = llmService
        self.configProvider = configProvider
    }

    /// LLM 服务是否已就绪
    func isReady() -> Bool {
        llmService != nil
    }

    /// 对指定项目执行深度分析
    ///
    /// - Parameter projectPath: 项目根路径
    /// - Returns: 发现的问题列表，如果服务未就绪或分析失败则返回 nil
    func analyze(projectPath: String) async -> [ProjectIssue]? {
        guard let llmService, let configProvider else {
            return nil
        }

        // TODO: 实现 LLM 深度分析
        // 1. 收集项目上下文（文件列表、最近变更等）
        // 2. 选择最有价值的文件/模块进行分析
        // 3. 构建 system prompt 和 user prompt
        // 4. 调用 LLM 分析
        // 5. 解析响应为 ProjectIssue 列表
        return nil
    }
}
