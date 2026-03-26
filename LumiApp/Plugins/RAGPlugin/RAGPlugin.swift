import MagicKit
import SwiftUI

/// RAG 插件
///
/// 提供检索增强生成 (RAG) 功能，让 AI 能够基于项目代码回答问题。
///
/// ## 功能
/// - 提供 RAG 中间件，拦截消息并检索相关文档
/// - 自动索引当前项目
///
/// ## 工作流程
/// 1. 用户发送消息
/// 2. 中间件判断是否需要 RAG
/// 3. 如果需要，调用 Context 中的 ragService 检索相关文档
/// 4. 将检索结果附加到消息上下文
///
actor RAGPlugin: SuperPlugin, SuperLog {
    
    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "🦞"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    
    static let id = "rag"
    static let navigationId: String = "rag_settings"
    static let displayName = String(localized: "RAG")
    static let description = String(localized: "Retrieval-Augmented Generation", table: "RAG")
    static let iconName = "doc.text.magnifyingglass"
    static let isConfigurable: Bool = true
    static var order: Int { 200 }
    
    nonisolated var instanceLabel: String { Self.id }
    static let shared = RAGPlugin()
    
    // MARK: - State
    
    /// 是否启用 RAG
    private var isEnabled: Bool = true
    
    /// 已索引的项目路径
    private var indexedProjects: Set<String> = []
    
    // MARK: - Initialization
    
    init() {
        AppLogger.rag.info("\(Self.t)🦞 RAG 插件已加载")
    }
    
    // MARK: - Plugin Conformance
    
    @MainActor
    func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                RAGSettingsView(plugin: self)
            }
        ]
    }
    
    // MARK: - Middleware
    
    /// 获取 RAG 中间件
    ///
    /// 这个中间件会：
    /// 1. 拦截用户消息
    /// 2. 判断是否需要 RAG 检索
    /// 3. 调用 Context 中的 ragService 检索相关文档
    @MainActor
    func getMiddleware() -> RAGMiddleware {
        return RAGMiddleware(plugin: self)
    }
    
    // MARK: - Public Methods
    
    /// 启用 RAG
    func enable() {
        isEnabled = true
        AppLogger.rag.info("\(Self.t)✅ RAG 已启用")
    }
    
    /// 禁用 RAG
    func disable() {
        isEnabled = false
        AppLogger.rag.info("\(Self.t)❌ RAG 已禁用")
    }
    
    /// 检查是否启用
    func checkEnabled() async -> Bool {
        return isEnabled
    }
    
    /// 索引项目
    func indexProject(at path: String, ragService: RAGService) async throws {
        guard !indexedProjects.contains(path) else {
            AppLogger.rag.info("\(Self.t)⏭️ 项目已索引: \(path)")
            return
        }
        
        // 初始化服务
        try await ragService.initialize()
        
        // 索引项目
        try await ragService.indexProject(at: path)
        
        indexedProjects.insert(path)
        AppLogger.rag.info("\(Self.t)✅ 项目索引完成: \(path)")
    }
}

// MARK: - RAG Middleware

/// RAG 中间件
///
/// 集成到消息发送管线，自动检索相关文档。
@MainActor
final class RAGMiddleware: SendMiddleware {
    
    let id: String = "rag"
    let order: Int = 100  // 在其他中间件之后执行
    
    private let plugin: RAGPlugin
    
    /// 触发 RAG 的关键词
    private let ragTriggers = ["项目", "代码", "功能", "文件", "实现", "在哪", "怎么", "如何"]
    
    init(plugin: RAGPlugin) {
        self.plugin = plugin
    }
    
    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        // 检查是否启用
        let isEnabled = await plugin.checkEnabled()
        guard isEnabled else {
            await next(ctx)
            return
        }
        
        let userMessage = ctx.message.content
        
        AppLogger.rag.info("🔀 RAG 中间件: 检查消息")
        AppLogger.rag.info("   用户消息: \"\(userMessage)\"")
        
        // 判断是否需要 RAG
        guard shouldUseRAG(for: userMessage) else {
            AppLogger.rag.info("   ⏭️ 跳过 RAG (不符合触发条件)")
            await next(ctx)
            return
        }
        
        AppLogger.rag.info("   ✅ 触发 RAG 检索")
        
        // 执行 RAG 检索
        do {
            // 初始化服务
            try await ctx.ragService.initialize()
            
            // 检索相关文档
            let response = try await ctx.ragService.retrieve(query: userMessage, topK: 3)
            
            guard response.hasResults else {
                AppLogger.rag.info("   ⚠️ 未找到相关文档")
                await next(ctx)
                return
            }
            
            // 打印检索结果
            AppLogger.rag.info("   📄 找到 \(response.results.count) 个相关文档:")
            for (index, result) in response.results.enumerated() {
                AppLogger.rag.info("      [\(index + 1)] \(result.source) (相似度: \(String(format: "%.2f", result.score)))")
                AppLogger.rag.info("          \(result.content.prefix(50))...")
            }
            
            // 构建增强提示词
            let augmentedPrompt = buildAugmentedPrompt(query: userMessage, results: response.results)
            
            AppLogger.rag.info("   📝 已构建增强提示词 (\(augmentedPrompt.count) 字符)")
            AppLogger.rag.info("   ➡️ 继续传递给 LLM...")
            
            // 在实际实现中，这里会修改 ctx.message 或添加额外信息
            // 目前只是演示流程
            
        } catch {
            AppLogger.rag.error("   ❌ RAG 检索失败: \(error)")
        }
        
        // 继续传递给下游
        await next(ctx)
    }
    
    // MARK: - Private
    
    private func shouldUseRAG(for message: String) -> Bool {
        let lowercased = message.lowercased()
        return ragTriggers.contains { lowercased.contains($0) }
    }
    
    private func buildAugmentedPrompt(query: String, results: [RAGSearchResult]) -> String {
        var prompt = "基于以下相关文档回答用户问题:\n\n---\n相关文档:\n"
        
        for (index, result) in results.enumerated() {
            prompt += "\n[文档 \(index + 1)] 来源: \(result.source)\n\(result.content)\n"
        }
        
        prompt += "\n---\n用户问题: \(query)\n\n请基于以上文档内容回答。"
        
        return prompt
    }
}

// MARK: - Settings View

@MainActor
struct RAGSettingsView: View {
    let plugin: RAGPlugin
    @State private var isEnabled = true
    
    var body: some View {
        Form {
            Section {
                Toggle("启用 RAG", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, newValue in
                        Task {
                            if newValue {
                                await plugin.enable()
                            } else {
                                await plugin.disable()
                            }
                        }
                    }
            } header: {
                Text("检索增强生成")
            } footer: {
                Text("启用后，AI 可以基于项目代码回答问题")
            }
            
            Section {
                LabeledContent("状态") {
                    Text("已就绪")
                        .foregroundStyle(.green)
                }
                LabeledContent("向量模型") {
                    Text("all-MiniLM-L6-v2 (模拟)")
                }
                LabeledContent("向量数据库") {
                    Text("LanceDB (模拟)")
                }
            } header: {
                Text("系统信息")
            }
            
            Section {
                Text("""
                RAG (Retrieval-Augmented Generation) 是一种让 AI 能够查阅项目代码的技术。
                
                工作流程:
                1. 索引项目文件
                2. 用户提问时搜索相关代码
                3. AI 基于找到的代码回答问题
                
                这样 AI 就能准确回答关于你项目的问题了。
                """)
                .font(.footnote)
                .foregroundStyle(.secondary)
            } header: {
                Text("关于 RAG")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Preview

#Preview("Settings") {
    RAGSettingsView(plugin: RAGPlugin.shared)
        .inRootView()
}