# Lumi 本地 RAG 实施方案（Swift + SQLite）

## 1. 目标与约束

- 目标：在 Lumi 内实现真正可用的本地 RAG（索引 + 检索 + 注入上下文）。
- 约束：
- 全本地运行，不依赖云端服务。
- Swift 优先，复杂逻辑集中在 `Core/Services/RAG`。
- `RAGPlugin` 仅负责触发与编排，不承载复杂业务。
- 优先保证稳定性与可维护性，再逐步优化召回质量与性能。

## 2. 当前现状与问题

- 当前 `RAGService` 为 mock 实现，未持久化、未扫描真实项目、未生成真实向量。
- `RAGSendMiddleware` 已构建增强提示词，但未实际注入 LLM 请求消息。
- `SendMessageContext` 每轮新建 `RAGService`，导致服务状态无法复用（索引生命周期不可控）。

## 3. 总体架构

### 3.1 职责边界

- `Plugins/RAGPlugin`：
- 判断是否触发 RAG。
- 调用 `RAGService` 完成检索。
- 将检索上下文写入本轮临时提示（不落库）。

- `Core/Services/RAG`：
- 索引、分块、向量生成、数据库持久化、相似度检索、上下文构建。
- 对上暴露高层接口（`ensureIndexed`、`retrieve`、`buildContext`）。

### 3.2 生命周期

- `RAGService` 在 `RootViewContainer` 中单例注入。
- `SendMessageContext` 持有共享 `ragService` 引用，不再自行 `init`。
- 每轮发送使用 `transientSystemPrompts` 承载 RAG 上下文，发送后丢弃。

### 3.3 存储方案

- DB 路径：`AppConfig.getPluginDBFolderURL("RAGPlugin")/rag.sqlite`
- 数据实体建议：
- `rag_documents`：文档级元数据（项目、文件、mtime、hash）。
- `rag_chunks`：分块文本与位置信息。
- `rag_embeddings`：chunk 向量（BLOB）及模型版本信息。
- `rag_index_state`：索引版本、最后扫描时间、参数快照。

## 4. 代码改造计划

## 阶段 M1：发送链路打通（先让 RAG 真正生效）

- 修改 `RootViewContainer`：
- 新增 `let ragService: RAGService` 单例。

- 修改 `SendMessageContext`：
- 通过构造参数注入 `ragService`。
- 新增 `var transientSystemPrompts: [String] = []`。

- 修改 `SendController`：
- 在 `beginSendFromQueue` 传入共享 `ragService`。
- 在 `streamAssistantReply` 发送前合成临时消息数组：
- 原历史消息 + `transientSystemPrompts`（作为 system 消息）再发给 LLM。
- 不将 RAG 注入内容落库，避免污染对话历史与驱动逻辑。

## 阶段 M2：真实索引与检索闭环（SQLite 版本）

- 在 `Core/Services/RAG` 拆分模块：
- `RAGService.swift`：门面与编排。
- `RAGSchema.swift`：建表与迁移。
- `RAGSQLiteStore.swift`：sqlite3 读写封装。
- `RAGChunker.swift`：按语言分块（代码/文档）。
- `RAGIndexer.swift`：全量/增量索引。
- `RAGRetriever.swift`：TopK 召回与打分。
- `RAGContextBuilder.swift`：提示词构建（含引用来源）。

- 最小能力：
- 扫描项目文本文件（先过滤二进制与超大文件）。
- 按 chunk 策略切分。
- 生成 embedding（可先接现有本地能力；接口可替换）。
- 保存向量与元数据。
- 查询时按相似度返回 topK。

## 阶段 M3：增量更新与质量优化

- 增量索引依据：`filePath + mtime + contentHash`。
- 索引策略：
- 首次进入项目触发后台全量索引。
- 后续按需增量更新（发送前检测过期）。
- 召回优化：
- 多路召回（文件名命中 + 向量相似度）。
- chunk 重排与去重。
- 文本拼接预算控制（token/字符上限）。

## 阶段 M4（可选）：sqlite-vec 加速

- 若引入 `sqlite-vec`：
- 增加扩展加载与可用性检测（失败自动降级到纯 SQLite 打分）。
- 保持 SQL/数据结构兼容，避免锁定单一路径。

## 5. RAG 中间件行为规范

- 触发条件：
- 保留关键词触发作为默认策略。
- 预留开关：`always on / keyword / off`。

- 执行流程：
1. 判断是否触发。
2. `ragService.initializeIfNeeded()`
3. `ragService.ensureIndexed(projectPath)`
4. `ragService.retrieve(query, topK)`
5. 构造上下文并写入 `ctx.transientSystemPrompts`
6. `await next(ctx)`

- 失败降级：
- RAG 失败不阻断对话，记录日志并走普通发送流程。

## 6. 验收标准

- 功能验收：
- 提问“某功能/文件/实现在哪”能引用真实项目片段回答。
- 关闭 RAG 后行为回退到原始流程。

- 性能验收：
- 首次索引可完成且不中断 UI。
- 索引后常见问题检索延迟可接受（目标 < 500ms，视项目规模调整）。

- 稳定性验收：
- 索引/检索异常不导致发送流程中断。
- 数据库损坏或版本不匹配可自动重建。

## 7. 风险与应对

- embedding 模型维度变更导致历史向量失效：
- 在 `rag_index_state` 记录 `embeddingModelId + dimension + version`，不一致即触发重建。

- 大项目索引耗时长：
- 分批写入、限流、后台任务、可取消机制。

- 上下文过长影响模型回答：
- 上下文预算器按字符/token 截断，并保留来源信息。

## 8. 任务拆解建议（可直接建 issue）

1. 注入共享 `RAGService`，增加 `transientSystemPrompts`。
2. 打通发送前临时 system 注入，不落库。
3. 落地 RAG SQLite schema + migration。
4. 落地项目扫描与 chunker（含文件过滤规则）。
5. 落地 embedding 接口与向量持久化。
6. 落地检索与上下文构建。
7. 接入 `RAGSendMiddleware` 全流程。
8. 增量索引与重建策略。
9. 加入日志、错误降级、回归测试。

## 9. 里程碑预估

- M1：1-2 天（链路打通）。
- M2：2-4 天（可用闭环）。
- M3：2-3 天（增量与稳定性）。
- M4：可选（性能增强）。

