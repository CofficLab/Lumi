# #130 研究与修复记录

## 结论摘要

issue #130 提出的修复方向**部分不成立**，其中「缓存模型实例 + 并行化 embedBatch」的组合会导致
**堆内存损坏与进程崩溃**。本记录列出实测数据与最终采用的方案。

## 实测数据

### 1. NLEmbedding 实例非线程安全（致命）

并发调用同一实例的 `vector(for:)` 会破坏堆内存：

```
exception: EXC_BREAKPOINT, SIGTRAP
asi: libsystem_malloc: BUG IN CLIENT OF LIBMALLOC: memory corruption of free block
  Montreal  MRLNeuralNetworkSetInput
  CoreNLP   ContextualWordEmbedding::fillWordVectors
  NaturalLanguage -[NLEmbedding vectorForString:]
```

| 模式 | 结果 |
|------|------|
| 共享同一实例 + 并发 | **崩溃**（稳定复现，exit 139/134/133） |
| 每任务独立实例 + 并发 | 安全（10 轮 × 4 并发 = 40 次调用全过） |

因此 issue 的「方向 1（缓存共享实例）」+「方向 3（并行 embedBatch）」组合**自相矛盾**。

### 2. 模型缓存几乎不省 CPU（推翻 issue 的成本归因）

`NLEmbedding.sentenceEmbedding(for:)` 每次返回**新实例**（`a !== b`），但底层模型是全局共享的：

| 场景（8 条 4000 字符） | 耗时 |
|------|------|
| 预热后 每次新建实例 + vector | 6.485 s |
| 预热后 复用单个实例 + vector | 6.483 s |

差异在噪声内。缓存的价值不在省 CPU，而在**避免无效查询**（见第 4 点）。

### 3. 真正瓶颈：句子级 embedding 对长文本做逐词神经网络推理

耗时与文本长度**线性相关**：

| 文本长度 | `sentenceEmbedding.vector(for:)` |
|------|------|
| 1850 字符 | 0.544 s |
| 7400 字符 | 2.047 s |
| 29600 字符 | 7.601 s |
| 74000 字符 | 19.778 s |

单次调用内部已多核并行（CPU/墙钟 ≈ 2~4），**本层再并行无收益**：

```
串行     并发=1: wall=1.73 s, CPU=6.92 s, 并行度=3.99 核
本层并发 并发=2: wall=1.56 s, CPU=6.67 s, 并行度=4.27 核
本层并发 并发=4: wall=1.99 s, CPU=7.28 s, 并行度=3.66 核
```

墙钟持平、CPU 总量不变——本层并发只是把同一份工作重新切分，反而增加与前台争抢。

### 4. 现状「词级降级」路径对多词文本完全无效

`wordEmbedding.vector(for:)` 只接受**单个词**，多词文本返回 `nil`：

| 输入 | 结果 |
|------|------|
| `hello` | dim 300 ✅ |
| `hello world` | nil ❌ |
| 长文本 | nil ❌ |

即现状代码在句子级模型不可用时，会一路回退到 **hash 伪向量**（无语义）。

### 5. 词级逐词平均：快 21 倍且语义可用

| 方式（100 行文本） | 耗时 |
|------|------|
| 句子级整段 | 0.810 s |
| 词级逐词平均 | 0.038 s |

## 最终方案

### A. 模型池（`NLEmbeddingModelPool.swift`）

按「泳道」独占分配：每条泳道持有自己的模型缓存与 `NLLanguageRecognizer`，
同一时刻只允许一个调用方持有。池满时等待归还，绝不退化到共享实例。

解决：
- 并发崩溃（issue 建议方案的致命缺陷）
- 重复的 `NLLanguageRecognizer` 构造成本
- 重复的无效模型查询（`traditionalChinese` 根本没有模型，实测 `sentence=nil word=nil`，
  现状每条文本都要白查一次）

### B. 按文本长度选择向量化策略

这是**性能收益的主体**。

句子级模型对整段文本做**逐词**神经网络推理，耗时与长度线性相关：

| 文本长度 | 句子级 `vector(for:)` |
|------|------|
| 1850 字符 | 0.544 s |
| 7400 字符 | 2.047 s |
| 29600 字符 | 7.601 s |
| 74000 字符 | 19.778 s |

词级模型只对**单个词**推理再求平均，耗时几乎与长度无关：

| 方式（10 个 4000 字符 chunk） | 耗时 |
|------|------|
| 句子级整段 | 9.549 s |
| 词级逐词平均 | 0.499 s（**快 19 倍**） |

预分块后再做句子级几乎无改善（8.0s），说明成本来自「逐词推理」本身，而非「一次处理长文本」。

因此采用**阈值策略**：

- `text.count <= 1500` → 句子级（语义质量最好）
- 超过阈值 → 词级逐词平均（快约 19 倍）

实测（12 个 chunk，平均 3030 字符）：

```
修复前（句子级整段）: wall=4.86 s  CPU=9.49 s
修复后（阈值策略）  : wall=0.22 s  CPU=0.22 s
```

**wall 降低 95.5%，CPU 降低 97.7%。**

语义分离度对比（余弦相似度，7 对文本）：

| 方式 | 相关均值 | 不相关均值 | 分离度 |
|------|------|------|------|
| 句子级 | 0.641 | 0.481 | 0.159 |
| 词级平均 | 0.663 | 0.448 | **0.215** |

词级平均的平均分离度略高于句子级；个别相关文本对得分偏低
（如 `swift concurrency actor` vs `async await task actor isolation` = 0.485），
属词袋模型的固有局限。短文本走句子级可规避该问题。

### C. 修复失效的词级降级路径

现状代码把整段文本直接传给 `wordEmbedding.vector(for:)`，
而该 API **只接受单个词**，多词文本一律返回 `nil`：

| 输入 | 结果 |
|------|------|
| `hello` | dim 300 ✅ |
| `hello world` | nil ❌ |
| 长文本 | nil ❌ |

即现状在句子级模型不可用时，会一路回退到 **hash 伪向量**（无语义）。
修复后改为用 `NLTokenizer` 分词、逐词求向量再平均，让降级路径真正可用。

### D. 不做本层并行

实测本层并发无收益且加剧前台争抢，改为**串行 + 有界**。

### E. 索引循环内让出时间片

`RAGIndexer.indexFiles` 每个文件处理完 `await Task.yield()`。

实测主线程事件循环间隔：

```
基线(无负载)      : 平均=49.4 ms  最大= 61.7 ms
协程池 CPU 密集 x4 : 平均=52.7 ms  最大=151.8 ms  ← 尖刺 2.5x
```

`RAGService` 是 actor，`indexFiles` 原本是同步函数，长时间独占协作线程导致主 actor
调度延迟上升。让出时间片把 CPU 归还给前台。

### F. Swift 6 严格并发适配

`RAGIndexer` 改为 `Sendable`，`onProgress` 改为 `@Sendable` 闭包，
`RAGChunker` 标记 `Sendable`（纯值类型）。索引方法改为 `async` 以支持让出时间片。

## 修复内容清单

| 文件 | 变更 |
|------|------|
| `Providers/NLEmbeddingModelPool.swift` | 新增：独占泳道模型池 |
| `Providers/AppleNativeEmbeddingProvider.swift` | 阈值策略 + 词级平均 + 使用模型池 |
| `Services/RAGIndexer.swift` | `async` + `Task.yield()` + `Sendable` 适配 |
| `Services/RAGService.swift` | 适配 `async` 调用与 `@Sendable` 回调 |
| `Services/RAGChunker.swift` | 标记 `Sendable` |
| `Tests/ProjectRAGEngineTests/AppleNativeEmbeddingProviderTests.swift` | 新增 16 个测试 |

## 未采纳 issue 的建议及原因

| issue 建议 | 是否采纳 | 原因 |
|-----------|---------|------|
| 缓存 NLEmbedding 模型实例 | ✅ 部分采纳 | 采纳缓存，但**必须按泳道独占**；共享单例 + 并行会崩溃 |
| 复用 NLLanguageRecognizer | ✅ 采纳 | 消除重复的语言模型加载 |
| 并行化 embedBatch | ❌ 不采纳 | libBNNS 内部已多核并行，本层并发墙钟持平、CPU 不降，反而加剧前台争抢 |
| RAGIndexer 加 CPU 预算 | ✅ 采纳（`Task.yield()`） | 抑制主线程 151ms 尖刺 |
| 空闲时再索引 | ❌ 已有实现 | `RAGIndexScheduler` 已用 `IdleTimeProviding` 判断 |

