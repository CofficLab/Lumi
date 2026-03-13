# 改进建议：对话记忆与上下文管理

**参考产品**: Cursor, Claude Code, ChatGPT  
**优先级**: 🟡 中  
**影响范围**: ChatHistoryService, Conversation, ContextService

---

## 背景

Cursor 和 Claude Code 都实现了智能的对话记忆系统：

- 自动总结长对话历史
- 提取关键信息和决策
- 跨会话记忆
- 项目级别的长期记忆

当前 Lumi 的 `ChatHistoryService` 可能缺少这些高级记忆功能。

---

## 改进方案

### 1. 对话历史压缩

```swift
/// 对话历史压缩器
class ConversationCompressor {
    let llmService: LLMService
    
    /// 压缩阈值（token 数）
    let compressionThreshold: Int = 8000
    
    /// 压缩对话历史
    func compressIfNeeded(
        _ messages: [ChatMessage],
        maxTokens: Int
    ) async throws -> [ChatMessage] {
        let currentTokens = estimateTokens(messages)
        
        if currentTokens <= maxTokens {
            return messages
        }
        
        return try await compress(messages, targetTokens: maxTokens)
    }
    
    /// 执行压缩
    private func compress(
        _ messages: [ChatMessage],
        targetTokens: Int
    ) async throws -> [ChatMessage] {
        // 保留最近的几条消息
        let keepRecentCount = 3
        let recentMessages = Array(messages.suffix(keepRecentCount))
        
        // 压缩旧消息
        let oldMessages = Array(messages.dropLast(keepRecentCount))
        let summary = try await summarizeMessages(oldMessages)
        
        // 组合结果
        var result: [ChatMessage] = []
        
        // 添加摘要
        if !summary.isEmpty {
            result.append(ChatMessage(
                role: .system,
                content: "之前的对话摘要：\n\(summary)"
            ))
        }
        
        // 添加最近消息
        result.append(contentsOf: recentMessages)
        
        return result
    }
    
    /// 总结消息
    private func summarizeMessages(_ messages: [ChatMessage]) async throws -> String {
        let prompt = """
        请总结以下对话的关键信息：
        
        1. 讨论了哪些主题？
        2. 做出了什么决策？
        3. 确定了什么约定？
        4. 还有未解决的问题吗？
        
        对话内容：
        \(formatMessages(messages))
        
        请用简洁的要点形式总结：
        """
        
        let response = try await llmService.sendMessage(
            messages: [ChatMessage(role: .user, content: prompt)],
            config: currentConfig
        )
        
        return response.content
    }
    
    /// 估算 token 数
    private func estimateTokens(_ messages: [ChatMessage]) -> Int {
        // 简化估算
        messages.reduce(0) { sum, msg in
            sum + msg.content.count / 4
        }
    }
    
    /// 格式化消息
    private func formatMessages(_ messages: [ChatMessage]) -> String {
        messages.map { msg in
            "[\(msg.role.rawValue)]: \(msg.content)"
        }.joined(separator: "\n\n")
    }
}
```

---

### 2. 关键信息提取

```swift
/// 关键信息提取器
class KeyInformationExtractor {
    let llmService: LLMService
    
    /// 从对话中提取关键信息
    func extract(from messages: [ChatMessage]) async throws -> ExtractedInformation {
        let prompt = """
        从以下对话中提取关键信息：
        
        \(formatMessages(messages))
        
        请以 JSON 格式返回：
        {
            "decisions": ["决策1", "决策2"],
            "agreements": ["约定1", "约定2"],
            "entities": {
                "files": ["涉及的文件"],
                "functions": ["涉及的函数"],
                "concepts": ["涉及的概念"]
            },
            "actionItems": ["待办事项"],
            "questions": ["未解决的问题"]
        }
        """
        
        let response = try await llmService.sendMessage(
            messages: [ChatMessage(role: .user, content: prompt)],
            config: currentConfig
        )
        
        return try parseJSON(response.content)
    }
    
    /// 提取代码上下文
    func extractCodeContext(from messages: [ChatMessage]) async throws -> CodeContext {
        let prompt = """
        从对话中提取代码相关的上下文信息：
        
        \(formatMessages(messages))
        
        请返回：
        1. 讨论的主要代码文件
        2. 涉及的代码模式
        3. 使用的库和框架
        4. 编码风格偏好
        """
        
        let response = try await llmService.sendMessage(
            messages: [ChatMessage(role: .user, content: prompt)],
            config: currentConfig
        )
        
        return try parseCodeContext(response.content)
    }
}

/// 提取的信息
struct ExtractedInformation: Codable {
    let decisions: [String]
    let agreements: [String]
    let entities: EntityInfo
    let actionItems: [String]
    let questions: [String]
    
    struct EntityInfo: Codable {
        let files: [String]
        let functions: [String]
        let concepts: [String]
    }
}

/// 代码上下文
struct CodeContext: Codable {
    let files: [String]
    let patterns: [String]
    let libraries: [String]
    let stylePreferences: [String]
}
```

---

### 3. 长期记忆存储

```swift
/// 长期记忆存储
class LongTermMemoryStore {
    private let database: Database
    
    /// 存储记忆
    func store(_ memory: Memory) async throws {
        // 生成嵌入向量
        let embedding = try await generateEmbedding(memory.content)
        
        // 存储到数据库
        try database.insert(
            table: "memories",
            values: [
                "id": memory.id.uuidString,
                "content": memory.content,
                "type": memory.type.rawValue,
                "project_id": memory.projectId,
                "created_at": memory.createdAt,
                "embedding": embedding
            ]
        )
    }
    
    /// 检索相关记忆
    func search(query: String, limit: Int = 10) async throws -> [Memory] {
        // 生成查询嵌入
        let queryEmbedding = try await generateEmbedding(query)
        
        // 向量搜索
        let results = try database.query("""
            SELECT id, content, type, project_id, created_at,
                   cosine_similarity(embedding, ?) as score
            FROM memories
            WHERE project_id = ?
            ORDER BY score DESC
            LIMIT ?
            """, [queryEmbedding, currentProjectId, limit])
        
        return results.map { Memory(from: $0) }
    }
    
    /// 更新记忆
    func update(_ memory: Memory) async throws {
        try database.update(
            table: "memories",
            where: ["id": memory.id.uuidString],
            values: [
                "content": memory.content,
                "updated_at": Date()
            ]
        )
    }
    
    /// 删除过期记忆
    func cleanup(olderThan days: Int = 90) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        try database.delete(
            table: "memories",
            where: ["created_at <": cutoffDate]
        )
    }
    
    /// 生成嵌入向量
    private func generateEmbedding(_ text: String) async throws -> [Float] {
        // 调用嵌入 API
        // ...
    }
}

/// 记忆项
struct Memory: Identifiable, Codable {
    let id: UUID
    let content: String
    let type: MemoryType
    let projectId: String?
    let createdAt: Date
    let updatedAt: Date?
    let importance: Importance
    
    enum MemoryType: String, Codable {
        case decision      // 决策
        case agreement     // 约定
        case preference    // 偏好
        case fact          // 事实
        case pattern       // 模式
        case error         // 错误及解决方案
    }
    
    enum Importance: Int, Codable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
    }
}
```

---

### 4. 项目知识库

```swift
/// 项目知识库
class ProjectKnowledgeBase {
    private let memoryStore: LongTermMemoryStore
    
    /// 添加知识
    func addKnowledge(
        _ content: String,
        type: Memory.MemoryType,
        importance: Memory.Importance = .medium
    ) async throws {
        let memory = Memory(
            id: UUID(),
            content: content,
            type: type,
            projectId: currentProjectId,
            createdAt: Date(),
            updatedAt: nil,
            importance: importance
        )
        
        try await memoryStore.store(memory)
    }
    
    /// 从对话学习
    func learn(from conversation: Conversation) async throws {
        // 提取关键信息
        let extractor = KeyInformationExtractor()
        let info = try await extractor.extract(from: conversation.messages)
        
        // 存储决策
        for decision in info.decisions {
            try await addKnowledge(
                decision,
                type: .decision,
                importance: .high
            )
        }
        
        // 存储约定
        for agreement in info.agreements {
            try await addKnowledge(
                agreement,
                type: .agreement,
                importance: .high
            )
        }
        
        // 存储实体关系
        for file in info.entities.files {
            try await addKnowledge(
                "项目涉及文件: \(file)",
                type: .fact,
                importance: .low
            )
        }
    }
    
    /// 获取相关上下文
    func getRelevantContext(for query: String) async throws -> String {
        let memories = try await memoryStore.search(query: query, limit: 5)
        
        guard !memories.isEmpty else {
            return ""
        }
        
        var context = "## 项目知识\n\n"
        
        // 按类型分组
        let grouped = Dictionary(grouping: memories) { $0.type }
        
        for (type, items) in grouped {
            context += "### \(type.displayName)\n"
            for item in items {
                context += "- \(item.content)\n"
            }
            context += "\n"
        }
        
        return context
    }
    
    /// 手动添加知识（用户指令）
    func remember(_ content: String, importance: Memory.Importance = .medium) async throws {
        try await addKnowledge(content, type: .fact, importance: importance)
    }
    
    /// 遗忘知识
    func forget(keyword: String) async throws {
        // 搜索并删除匹配的记忆
        // ...
    }
}
```

---

### 5. 智能上下文注入

```swift
/// 智能上下文注入器
class SmartContextInjector {
    let knowledgeBase: ProjectKnowledgeBase
    let compressor: ConversationCompressor
    
    /// 为新对话构建上下文
    func buildContext(
        for query: String,
        conversationHistory: [ChatMessage],
        projectPath: String
    ) async throws -> ConversationContext {
        var context = ConversationContext()
        
        // 1. 获取项目相关知识
        let projectKnowledge = try await knowledgeBase.getRelevantContext(for: query)
        context.projectKnowledge = projectKnowledge
        
        // 2. 压缩对话历史
        let compressedHistory = try await compressor.compressIfNeeded(
            conversationHistory,
            maxTokens: 6000
        )
        context.conversationHistory = compressedHistory
        
        // 3. 添加系统提示词
        context.systemPrompt = buildSystemPrompt()
        
        // 4. 添加当前项目信息
        context.projectInfo = try await getProjectInfo(path: projectPath)
        
        return context
    }
    
    /// 构建系统提示词
    private func buildSystemPrompt() -> String {
        """
        你是一个智能编程助手。你正在帮助用户开发一个 macOS 应用。
        
        你可以访问以下上下文信息：
        1. 项目知识库：之前对话中确定的重要决策和约定
        2. 对话历史：压缩后的历史对话
        3. 项目信息：当前项目的基本信息
        
        请根据这些上下文提供准确、一致的帮助。
        """
    }
    
    /// 获取项目信息
    private func getProjectInfo(path: String) async throws -> String {
        // 分析项目结构，生成项目概要
        // ...
    }
}

/// 对话上下文
struct ConversationContext {
    var systemPrompt: String = ""
    var projectKnowledge: String = ""
    var conversationHistory: [ChatMessage] = []
    var projectInfo: String = ""
    
    /// 转换为消息列表
    func toMessages() -> [ChatMessage] {
        var messages: [ChatMessage] = []
        
        // 系统提示词
        var systemContent = systemPrompt
        if !projectKnowledge.isEmpty {
            systemContent += "\n\n" + projectKnowledge
        }
        if !projectInfo.isEmpty {
            systemContent += "\n\n" + projectInfo
        }
        messages.append(ChatMessage(role: .system, content: systemContent))
        
        // 对话历史
        messages.append(contentsOf: conversationHistory)
        
        return messages
    }
    
    /// 估算 token 数
    func estimateTokens() -> Int {
        let allText = toMessages().map { $0.content }.joined(separator: " ")
        return allText.count / 4
    }
}
```

---

### 6. 记忆管理 UI

```swift
/// 记忆管理视图
struct MemoryManagementView: View {
    @StateObject var viewModel: MemoryManagementViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                TextField("搜索记忆...", text: $viewModel.searchQuery)
                    .textFieldStyle(.roundedBorder)
                
                Picker("类型", selection: $viewModel.selectedType) {
                    Text("全部").tag(nil as Memory.MemoryType?)
                    Text("决策").tag(Memory.MemoryType.decision as Memory.MemoryType?)
                    Text("约定").tag(Memory.MemoryType.agreement as Memory.MemoryType?)
                    Text("偏好").tag(Memory.MemoryType.preference as Memory.MemoryType?)
                }
                .frame(width: 100)
            }
            .padding()
            
            Divider()
            
            // 记忆列表
            List(viewModel.filteredMemories) { memory in
                MemoryRowView(memory: memory)
                    .contextMenu {
                        Button("编辑") {
                            viewModel.edit(memory)
                        }
                        Button("删除") {
                            viewModel.delete(memory)
                        }
                        Button("提高重要性") {
                            viewModel.increaseImportance(memory)
                        }
                    }
            }
            
            Divider()
            
            // 底部操作栏
            HStack {
                Button("添加记忆") {
                    viewModel.showAddSheet = true
                }
                
                Spacer()
                
                Text("\(viewModel.memories.count) 条记忆")
                    .foregroundColor(.secondary)
                
                Button("清理过期记忆") {
                    Task {
                        await viewModel.cleanupOldMemories()
                    }
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddMemorySheet()
        }
    }
}

/// 记忆行视图
struct MemoryRowView: View {
    let memory: Memory
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 类型图标
            Image(systemName: memory.type.icon)
                .font(.title3)
                .foregroundColor(memory.type.color)
                .frame(width: 24)
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.content)
                    .font(.body)
                    .lineLimit(3)
                
                HStack(spacing: 8) {
                    Text(memory.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(memory.type.color.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(memory.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // 重要性指示
                    HStack(spacing: 2) {
                        ForEach(1...4, id: \.self) { i in
                            Circle()
                                .fill(i <= memory.importance.rawValue ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

---

## 实施计划

### 阶段 1: 压缩与总结 (1 周)
1. 实现 `ConversationCompressor`
2. 实现关键信息提取
3. 集成到对话流程

### 阶段 2: 长期记忆 (2 周)
1. 实现向量数据库集成
2. 实现 `LongTermMemoryStore`
3. 实现语义搜索

### 阶段 3: 知识库 (1 周)
1. 实现 `ProjectKnowledgeBase`
2. 实现智能上下文注入
3. 实现记忆管理 UI

---

## 预期效果

1. **上下文长度优化**: 通过压缩节省 50%+ token
2. **知识持久化**: 跨会话保持项目知识
3. **一致性提升**: AI 记住之前的决策和约定
4. **效率提升**: 减少重复说明

---

## 参考资源

- [LangChain Memory](https://python.langchain.com/docs/modules/memory/)
- [MemGPT](https://memgpt.ai/)
- [OpenAI Embeddings](https://platform.openai.com/docs/guides/embeddings)

---

*创建时间: 2026-03-13*