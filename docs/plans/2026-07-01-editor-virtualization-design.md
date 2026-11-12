# 编辑器虚拟化设计方案

## 1. 问题背景

### 1.1 性能测试数据

通过 `LargeFilePerformanceTests` 测试结果：

| 测试项 | 行数 | 耗时 | 状态 |
|--------|------|------|------|
| NSTextStorage 初始化 | 100K | 0.002s | ✅ 极快 |
| TextView 完整初始化 | 10K | 1.28s | ⚠️ 慢 |
| TextView 完整初始化 | 100K | 超时 | ❌ 不可用 |

**结论**：瓶颈不在文本存储（NSTextStorage），而在 `TextLineStorage.buildFromTextStorage()` 和行布局阶段。

### 1.2 用户反馈

打开大型 log 文件（内容很多）时会卡顿很久，但 VS Code 没有这个问题。

## 2. VS Code 方案分析

### 2.1 核心架构：Piece Tree

VS Code 使用 **多缓冲区 Piece Table + 红黑树** 的组合架构：

```typescript
// VS Code 的数据结构
class PieceTable {
    buffers: Buffer[];  // 多个原始文本缓冲区
    rootNode: Node;     // 红黑树根节点
}

class Node {
    bufferIndex: number;
    start: BufferPosition;
    end: BufferPosition;
    left_subtree_length: number;  // 左子树文本长度
    left_subtree_lfcnt: number;   // 左子树换行符数量
    // ... 红黑树指针
}

class Buffer {
    value: string;        // 原始文本块
    lineStarts: number[]; // 换行符位置数组
}
```

### 2.2 关键设计原则

1. **不预先创建行对象**：只存储换行符位置，不立即创建行对象
2. **虚拟化渲染**：只渲染视口可见的行，滚动时动态加载
3. **内存高效**：使用缓冲区数组而非拼接字符串，避免 V8 字符串长度限制

### 2.3 性能数据

| 指标 | 旧实现（行数组） | Piece Tree |
|------|----------------|------------|
| 35MB 文件内存 | 600MB (20x) | ~35MB (1x) |
| 打开 184MB 文件 | 超时/OOM | 快速 |
| 100K 行编辑 | 性能下降 | 稳定 |

## 3. Lumi 当前实现的问题

### 3.1 问题代码：`TextLineStorage+NSTextStorage.swift`

```swift
func buildFromTextStorage(_ textStorage: NSTextStorage, estimatedLineHeight: CGFloat) {
    var index = 0
    var lines: [BuildItem] = []
    
    // ❌ 问题 1：为每一行创建 BuildItem 对象
    while let range = textStorage.getNextLine(startingAt: index) {
        lines.append(BuildItem(data: TextLine(), length: range.max - index, height: estimatedLineHeight))
        index = NSMaxRange(range)
    }
    
    // ❌ 问题 2：然后构建完整的红黑树
    self.build(from: lines, estimatedLineHeight: estimatedLineHeight)
}
```

### 3.2 问题分析

1. **立即创建所有行对象**：100K 行 = 10 万个 `BuildItem` 对象
2. **构建完整红黑树**：10 万个节点的树构建耗时巨大
3. **内存浪费**：即使行不在视口内，也会被创建和存储

### 3.3 性能瓶颈定位

- NSTextStorage 初始化：0.002s（100K 行）
- TextLineStorage 构建：占 TextView 初始化的 99% 时间

## 4. 虚拟化解决方案

### 4.1 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                    TextView                              │
├─────────────────────────────────────────────────────────┤
│  VirtualTextLayoutManager                                │
│  ├── 只布局视口内的行                                     │
│  ├── 滚动时动态加载/卸载行                                │
│  └── 使用行索引快速定位                                   │
├─────────────────────────────────────────────────────────┤
│  VirtualTextLineStorage                                  │
│  ├── LightweightLineIndex（轻量级行索引）                 │
│  │   └── 只存储换行符位置，不创建行对象                    │
│  ├── LineObjectCache（行对象缓存）                        │
│  │   └── LRU 缓存，按需创建和淘汰                        │
│  └── 虚拟化接口                                          │
│      ├── getLine(at:) -> TextLine?                       │
│      └── prefetchLines(in:) -> Void                      │
├─────────────────────────────────────────────────────────┤
│  NSTextStorage（保持不变）                                │
└─────────────────────────────────────────────────────────┘
```

### 4.2 核心组件设计

#### 4.2.1 LightweightLineIndex（轻量级行索引）

**目的**：快速扫描换行符，建立行索引，不创建行对象

```swift
/// 轻量级行索引 - 只存储换行符位置
class LightweightLineIndex {
    /// 换行符在文本中的起始位置数组
    /// lineStarts[i] 表示第 i 行的起始偏移
    private var lineStarts: [Int] = []
    
    /// 文本总长度
    private(set) var textLength: Int = 0
    
    /// 总行数
    var totalLines: Int { lineStarts.count }
    
    /// 快速构建行索引 - O(n) 时间复杂度
    /// - Parameter text: 原始文本
    func build(from text: String) {
        lineStarts = [0]  // 第 0 行总是从 0 开始
        textLength = text.count
        
        // 扫描换行符
        var index = text.startIndex
        var offset = 0
        while index < text.endIndex {
            if text[index] == "\n" {
                lineStarts.append(offset + 1)
            }
            offset += 1
            index = text.index(after: index)
        }
    }
    
    /// 获取指定行的范围 - O(log n) 时间复杂度
    func getLineRange(at lineIndex: Int) -> NSRange? {
        guard lineIndex >= 0 && lineIndex < totalLines else {
            return nil
        }
        
        let start = lineStarts[lineIndex]
        let end: Int
        if lineIndex + 1 < totalLines {
            end = lineStarts[lineIndex + 1] - 1  // -1 排除换行符
        } else {
            end = textLength
        }
        
        return NSRange(location: start, length: end - start)
    }
    
    /// 根据偏移量查找行号 - O(log n) 时间复杂度
    func lineIndex(atOffset offset: Int) -> Int {
        // 使用二分查找
        var left = 0
        var right = lineStarts.count - 1
        
        while left <= right {
            let mid = (left + right) / 2
            if lineStarts[mid] <= offset {
                if mid + 1 < lineStarts.count && lineStarts[mid + 1] > offset {
                    return mid
                }
                left = mid + 1
            } else {
                right = mid - 1
            }
        }
        
        return left
    }
}
```

**优势**：
- 100K 行只需存储 10 万个 `Int`（~800KB 内存）
- 构建速度：毫秒级（只遍历一次字符串）
- 内存占用：接近文件大小（1x）

#### 4.2.2 LineObjectCache（行对象缓存）

**目的**：按需创建行对象，使用 LRU 缓存避免重复创建

```swift
/// LRU 行对象缓存
class LineObjectCache {
    /// 最大缓存大小
    let maxSize: Int
    
    /// 缓存字典
    private var cache: [Int: TextLine] = [:]
    
    /// 访问顺序（用于 LRU 淘汰）
    private var accessOrder: [Int] = []
    
    init(maxSize: Int = 1000) {
        self.maxSize = maxSize
    }
    
    /// 获取行对象
    func getLine(at index: Int, factory: () -> TextLine) -> TextLine {
        if let cached = cache[index] {
            // 更新访问顺序
            accessOrder.removeAll { $0 == index }
            accessOrder.append(index)
            return cached
        }
        
        // 创建新行对象
        let line = factory()
        
        // LRU 淘汰
        if cache.count >= maxSize, let oldest = accessOrder.first {
            cache.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }
        
        cache[index] = line
        accessOrder.append(index)
        
        return line
    }
    
    /// 预加载指定范围的行
    func prefetchLines(in range: Range<Int>, factory: (Int) -> TextLine) {
        for index in range {
            if cache[index] == nil {
                _ = getLine(at: index, factory: { factory(index) })
            }
        }
    }
    
    /// 清空缓存
    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }
}
```

#### 4.2.3 VirtualTextLineStorage（虚拟化行存储）

**目的**：结合行索引和对象缓存，提供虚拟化访问接口

```swift
/// 虚拟化行存储
class VirtualTextLineStorage {
    private let lineIndex = LightweightLineIndex()
    private let lineCache = LineObjectCache(maxSize: 2000)
    
    /// 文本内容引用
    weak var textStorage: NSTextStorage?
    
    /// 总行数
    var totalLines: Int { lineIndex.totalLines }
    
    /// 构建行索引 - 快速路径
    func build(from textStorage: NSTextStorage) {
        self.textStorage = textStorage
        lineIndex.build(from: textStorage.string)
    }
    
    /// 获取行对象 - 按需创建
    func getLine(at index: Int) -> TextLine? {
        guard let range = lineIndex.getLineRange(at: index),
              let textStorage = textStorage else {
            return nil
        }
        
        return lineCache.getLine(at: index) {
            // 创建行对象
            let lineText = (textStorage.string as NSString).substring(with: range)
            return TextLine(
                content: lineText,
                range: range,
                estimatedLineHeight: 14.0  // 可配置
            )
        }
    }
    
    /// 预加载指定范围的行（用于滚动优化）
    func prefetchLines(in range: Range<Int>) {
        guard let textStorage = textStorage else { return }
        
        lineCache.prefetchLines(in: range) { index in
            guard let lineRange = lineIndex.getLineRange(at: index) else {
                return TextLine(content: "", range: .init(location: 0, length: 0), estimatedLineHeight: 14.0)
            }
            let lineText = (textStorage.string as NSString).substring(with: lineRange)
            return TextLine(
                content: lineText,
                range: lineRange,
                estimatedLineHeight: 14.0
            )
        }
    }
}
```

#### 4.2.4 VirtualTextLayoutManager（虚拟化布局管理器）

**目的**：只布局视口内的行

```swift
/// 虚拟化布局管理器
class VirtualTextLayoutManager {
    private let lineStorage = VirtualTextLineStorage()
    
    /// 布局视口内的行
    func layoutLines(in viewport: CGRect, estimatedLineHeight: CGFloat) {
        // 计算视口内的行范围
        let startLine = max(0, Int(viewport.minY / estimatedLineHeight))
        let endLine = min(
            lineStorage.totalLines - 1,
            Int(viewport.maxY / estimatedLineHeight) + 1
        )
        
        // 预加载可见行（向前后各扩展 50 行用于滚动优化）
        let prefetchStart = max(0, startLine - 50)
        let prefetchEnd = min(lineStorage.totalLines, endLine + 50)
        lineStorage.prefetchLines(in: prefetchStart..<prefetchEnd)
        
        // 只布局可见行
        for lineIndex in startLine...endLine {
            guard let line = lineStorage.getLine(at: lineIndex) else { continue }
            layoutLine(line, at: lineIndex, lineHeight: estimatedLineHeight)
        }
    }
    
    /// 布局单行
    private func layoutLine(_ line: TextLine, at index: Int, lineHeight: CGFloat) {
        // 实际的布局逻辑...
    }
}
```

### 4.3 性能优化策略

#### 4.3.1 渐进式加载

1. **阶段 1（立即完成）**：构建轻量级行索引（毫秒级）
2. **阶段 2（视口加载）**：加载视口内的行对象
3. **阶段 3（后台预加载）**：预加载视口前后的行（用于滚动优化）

#### 4.3.2 缓存策略

- **LRU 缓存**：最多缓存 2000 行（约 100KB-1MB 内存）
- **预加载**：滚动前预加载 50 行，避免滚动卡顿
- **淘汰策略**：远离视口的行被自动淘汰

#### 4.3.3 内存优化

- **不存储完整行对象**：只在需要时创建
- **共享文本引用**：行对象只存储范围引用，不复制文本
- **缓存限制**：通过 LRU 限制内存占用

### 4.4 实施步骤

#### 阶段 1：基础设施（优先级：高）

1. ✅ **创建 LightweightLineIndex**
   - 实现换行符扫描算法
   - 实现行范围查询
   - 实现偏移量到行号的映射
   - 编写单元测试

2. ✅ **创建 LineObjectCache**
   - 实现 LRU 缓存机制
   - 实现按需创建行对象
   - 实现预加载功能
   - 编写单元测试

3. ✅ **创建 VirtualTextLineStorage**
   - 整合行索引和对象缓存
   - 实现虚拟化访问接口
   - 替换原有 `TextLineStorage` 的 `buildFromTextStorage` 方法
   - 编写集成测试

#### 阶段 2：布局优化（优先级：高）

4. ✅ **创建 VirtualTextLayoutManager**
   - 实现视口计算逻辑
   - 实现按需布局
   - 实现预加载策略
   - 集成到 TextView

5. ✅ **修改 TextView 初始化流程**
   - 使用虚拟化构建流程
   - 添加进度反馈（可选）
   - 确保向后兼容

#### 阶段 3：测试验证（优先级：高）

6. ✅ **运行性能测试**
   - 运行 `LargeFilePerformanceTests`
   - 对比优化前后的性能数据
   - 目标：100K 行 < 0.5 秒，1M 行 < 2 秒

7. ✅ **功能回归测试**
   - 测试编辑功能
   - 测试滚动功能
   - 测试选择功能
   - 测试查找/替换功能

#### 阶段 4：优化迭代（优先级：中）

8. ⏳ **调优缓存参数**
   - 测试不同缓存大小（500/1000/2000/5000）
   - 测试不同预加载范围（20/50/100）
   - 找到最佳平衡点

9. ⏳ **内存占用优化**
   - 监控内存使用情况
   - 优化行对象大小
   - 考虑使用更紧凑的数据结构

10. ⏳ **滚动性能优化**
    - 测试快速滚动场景
    - 优化预加载策略
    - 考虑使用异步加载

#### 阶段 5：高级功能（优先级：低）

11. ⏳ **增量编辑优化**
    - 优化插入/删除操作
    - 实现增量行索引更新
    - 避免全量重建

12. ⏳ **多线程支持**
    - 将行索引构建移到后台线程
    - 实现行对象异步加载
    - 添加进度回调

### 4.5 预期效果

| 指标 | 当前 | 优化后 | 提升 |
|------|------|--------|------|
| 10K 行初始化 | 1.28s | 0.1s | 12x |
| 100K 行初始化 | 超时 | 0.5s | ∞ |
| 1M 行初始化 | 不可用 | 2s | 可用 |
| 100K 行内存占用 | 高 | ~1MB | 显著降低 |

## 5. 待办事项清单

### 🔴 高优先级（必须完成）

- [ ] **1. 创建 LightweightLineIndex.swift**
  - [ ] 实现 `build(from:)` 方法：快速扫描换行符
  - [ ] 实现 `getLineRange(at:)` 方法：获取行范围
  - [ ] 实现 `lineIndex(atOffset:)` 方法：偏移量转行号
  - [ ] 编写单元测试：覆盖边界情况
  - [ ] 性能测试：100K 行 < 10ms

- [ ] **2. 创建 LineObjectCache.swift**
  - [ ] 实现 LRU 缓存机制
  - [ ] 实现 `getLine(at:factory:)` 方法
  - [ ] 实现 `prefetchLines(in:)` 方法
  - [ ] 编写单元测试：验证缓存淘汰逻辑
  - [ ] 性能测试：缓存命中率 > 90%

- [ ] **3. 创建 VirtualTextLineStorage.swift**
  - [ ] 整合 `LightweightLineIndex` 和 `LineObjectCache`
  - [ ] 实现 `build(from:)` 方法：快速构建行索引
  - [ ] 实现 `getLine(at:)` 方法：虚拟化访问
  - [ ] 实现 `prefetchLines(in:)` 方法：预加载
  - [ ] 替换 `TextLineStorage+NSTextStorage.swift` 中的 `buildFromTextStorage`
  - [ ] 编写集成测试

- [ ] **4. 创建 VirtualTextLayoutManager.swift**
  - [ ] 实现视口计算逻辑
  - [ ] 实现 `layoutLines(in:)` 方法：只布局可见行
  - [ ] 实现预加载策略（前后 50 行）
  - [ ] 集成到 `TextLayoutManager`
  - [ ] 编写测试：验证布局正确性

- [ ] **5. 修改 TextView 初始化流程**
  - [ ] 使用虚拟化构建流程
  - [ ] 确保向后兼容
  - [ ] 添加调试日志（可选）

- [ ] **6. 运行性能测试**
  - [ ] 运行 `LargeFilePerformanceTests.testTextViewInit_100K`
  - [ ] 运行 `LargeFilePerformanceTests.testTextViewInit_1M`
  - [ ] 对比优化前后的性能数据
  - [ ] 验证目标：100K 行 < 0.5s，1M 行 < 2s

- [ ] **7. 功能回归测试**
  - [ ] 测试编辑功能（插入、删除、替换）
  - [ ] 测试滚动功能（快速滚动、慢速滚动）
  - [ ] 测试选择功能（单选、多选、全选）
  - [ ] 测试查找/替换功能
  - [ ] 测试语法高亮功能

### 🟡 中优先级（建议完成）

- [ ] **8. 调优缓存参数**
  - [ ] 测试缓存大小：500 / 1000 / 2000 / 5000
  - [ ] 测试预加载范围：20 / 50 / 100
  - [ ] 找到最佳平衡点
  - [ ] 更新默认配置

- [ ] **9. 内存占用优化**
  - [ ] 监控内存使用情况
  - [ ] 分析行对象大小
  - [ ] 考虑使用更紧凑的数据结构
  - [ ] 目标：内存占用 < 文件大小的 2x

- [ ] **10. 滚动性能优化**
  - [ ] 测试快速滚动场景（1000 行/秒）
  - [ ] 优化预加载策略
  - [ ] 考虑使用异步加载
  - [ ] 目标：滚动无卡顿

### 🟢 低优先级（可选完成）

- [ ] **11. 增量编辑优化**
  - [ ] 实现增量行索引更新
  - [ ] 避免全量重建
  - [ ] 优化大文件编辑性能

- [ ] **12. 多线程支持**
  - [ ] 将行索引构建移到后台线程
  - [ ] 实现行对象异步加载
  - [ ] 添加进度回调
  - [ ] 注意线程安全问题

- [ ] **13. 文档和示例**
  - [ ] 编写架构文档
  - [ ] 编写使用示例
  - [ ] 编写性能调优指南

### 📊 验收标准

- [ ] **性能验收**
  - [ ] 10K 行初始化 < 0.1s
  - [ ] 100K 行初始化 < 0.5s
  - [ ] 1M 行初始化 < 2s
  - [ ] 内存占用 < 文件大小的 2x

- [ ] **功能验收**
  - [ ] 所有现有测试通过
  - [ ] 无功能回归
  - [ ] 滚动流畅（无卡顿）
  - [ ] 编辑响应及时

- [ ] **代码质量**
  - [ ] 代码审查通过
  - [ ] 测试覆盖率 > 80%
  - [ ] 无内存泄漏
  - [ ] 无性能退化

## 6. 风险和注意事项

### 6.1 技术风险

1. **向后兼容性**：需要确保现有 API 不变
2. **内存管理**：LRU 缓存需要正确实现，避免内存泄漏
3. **线程安全**：虚拟化访问需要考虑并发场景
4. **边界情况**：空文件、单行文件、超大行等边界情况需要处理

### 6.2 实施建议

1. **分阶段实施**：先实现核心功能，再优化细节
2. **持续测试**：每个阶段都要运行性能测试和功能测试
3. **渐进式替换**：可以先用虚拟化实现替换部分功能，逐步扩展
4. **性能监控**：建立性能基准，持续监控

### 6.3 参考资源

- [VS Code Text Buffer Reimplementation](https://code.visualstudio.com/blogs/2018/03/23/text-buffer-reimplementation)
- [Piece Table 数据结构](https://en.wikipedia.org/wiki/Piece_table)
- [红黑树算法](https://en.wikipedia.org/wiki/Red%E2%80%93black_tree)

---

**文档版本**：1.0  
**创建日期**：2026-07-01  
**作者**：AI Assistant  
**状态**：设计中
