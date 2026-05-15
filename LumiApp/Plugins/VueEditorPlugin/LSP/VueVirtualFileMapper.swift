import Foundation
import os

/// Vue 虚拟文件映射器
///
/// 在 Volar 的混合模式 (Hybrid Mode) 下，Volar 内部已经处理了
/// `.vue` → `.vue.ts` + `.vue.html` + `.vue.css` 的虚拟文件拆分。
///
/// 本模块的主要职责是：
/// 1. 在 Lumi 侧维护 SFC 区块信息，用于编辑器增强功能
/// 2. 在文件变动时判断受影响的区块，辅助增量更新
/// 3. 为诊断坐标转换提供区块偏移量表
struct VueVirtualFileMapper: Sendable {
    nonisolated static let emoji = "🗺️"
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor.virtual-mapper"
    )

    // MARK: - 虚拟文件类型

    /// Volar 生成的虚拟文件类型
    enum VirtualFileType: String, Sendable {
        case template = "html"    // .vue.html
        case script = "ts"        // .vue.ts (或 .vue.js)
        case style = "css"        // .vue.css (或 .vue.scss 等)

        /// 虚拟文件扩展名
        var fileExtension: String { rawValue }

        /// 对应的 SFC 区块类型
        var blockType: SFCBlockType {
            switch self {
            case .template: return .template
            case .script: return .script
            case .style: return .style
            }
        }
    }

    // MARK: - 区块映射信息

    /// 区块在虚拟文件和真实文件中的映射关系
    struct BlockMapping: Sendable {
        /// 区块类型
        let blockType: SFCBlockType

        /// 虚拟文件类型
        let virtualType: VirtualFileType

        /// 区块在真实 .vue 文件中的起始行
        let realStartLine: Int

        /// 区块在真实 .vue 文件中的结束行
        let realEndLine: Int

        /// 区块内容在虚拟文件中的起始行（通常是 0）
        let virtualStartLine: Int

        /// 区块内容的行数
        let contentLineCount: Int

        /// 区块在真实文件中的起始字符偏移量（UTF-16）
        let realStartOffset: Int

        /// 区块语言（如 "ts", "scss", "less"）
        let lang: String?
    }

    // MARK: - 文件快照

    /// .vue 文件的映射快照
    struct FileMapping: Sendable {
        /// 原始文件 URI
        let uri: String

        /// 所有区块映射
        let blockMappings: [BlockMapping]

        /// 解析时间戳
        let timestamp: Date

        /// 文件内容的哈希（用于快速判断是否需要重新解析）
        let contentHash: Int

        // MARK: - 查询

        /// 根据 LSP 返回的虚拟文件行号，映射回真实文件行号
        ///
        /// - Parameters:
        ///   - virtualLine: 虚拟文件中的行号
        ///   - virtualType: 虚拟文件类型
        /// - Returns: 真实文件中的行号，无法映射时返回 nil
        func realLine(virtualLine: Int, in virtualType: VirtualFileType) -> Int? {
            guard let mapping = blockMappings.first(where: { $0.virtualType == virtualType }) else {
                return nil
            }

            // 虚拟文件行号 → 区块内容行号
            let contentLine = virtualLine - mapping.virtualStartLine
            guard contentLine >= 0 && contentLine < mapping.contentLineCount else {
                return nil
            }

            // 区块内容行号 → 真实文件行号
            return mapping.realStartLine + 1 + contentLine // +1 跳过开标签行
        }

        /// 根据真实文件行号，判断所在区块
        func blockAt(realLine: Int) -> BlockMapping? {
            blockMappings.first { realLine >= $0.realStartLine && realLine <= $0.realEndLine }
        }

        /// 根据区块类型查找映射
        func mapping(for blockType: SFCBlockType) -> BlockMapping? {
            blockMappings.first { $0.blockType == blockType }
        }
    }

    // MARK: - 缓存

    /// 文件映射缓存（uri → FileMapping）
    nonisolated(unsafe) private static var cache: [String: FileMapping] = [:]
    private static let cacheLock = NSLock()

    // MARK: - 公开方法

    /// 解析 .vue 文件并构建虚拟映射
    ///
    /// - Parameters:
    ///   - uri: 文件 URI
    ///   - content: .vue 文件完整内容
    /// - Returns: 文件映射
    static func map(uri: String, content: String) -> FileMapping {
        let hash = content.hashValue

        // 检查缓存
        cacheLock.lock()
        if let cached = cache[uri], cached.contentHash == hash {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        // 解析 SFC 区块
        let blocks = SFCBlock.parse(from: content)
        let mappings = buildBlockMappings(blocks: blocks, content: content)

        let fileMapping = FileMapping(
            uri: uri,
            blockMappings: mappings,
            timestamp: Date(),
            contentHash: hash
        )

        // 更新缓存
        cacheLock.lock()
        cache[uri] = fileMapping
        // 清理旧缓存（超过 50 个文件时）
        if cache.count > 50 {
            let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(cache.count - 30)
            for (key, _) in toRemove {
                cache.removeValue(forKey: key)
            }
        }
        cacheLock.unlock()

        return fileMapping
    }

    /// 获取缓存的映射（不重新解析）
    static func cachedMapping(uri: String) -> FileMapping? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache[uri]
    }

    /// 清除指定文件的缓存
    static func invalidate(uri: String) {
        cacheLock.lock()
        cache.removeValue(forKey: uri)
        cacheLock.unlock()
    }

    /// 清除所有缓存
    static func invalidateAll() {
        cacheLock.lock()
        cache.removeAll()
        cacheLock.unlock()
    }

    // MARK: - 私有方法

    /// 从 SFC 区块构建映射关系
    private static func buildBlockMappings(blocks: [SFCBlock], content: String) -> [BlockMapping] {
        var mappings: [BlockMapping] = []

        let lines = content.components(separatedBy: "\n")
        var currentOffset = 0

        // 计算每行的起始偏移量
        var lineOffsets = [Int](repeating: 0, count: lines.count)
        for (i, line) in lines.enumerated() {
            lineOffsets[i] = currentOffset
            currentOffset += line.utf16.count + 1 // +1 for \n
        }

        for block in blocks {
            let virtualType: VirtualFileType
            switch block.type {
            case .template: virtualType = .template
            case .script: virtualType = .script
            case .style: virtualType = .style
            }

            let contentLineCount = block.content.components(separatedBy: "\n").count

            let startOffset: Int
            if block.startLine < lineOffsets.count {
                // 区块内容的起始偏移 = 开标签行的偏移 + 开标签的长度 + 1
                let openTagLine = lines[block.startLine]
                let openTagLength = openTagLine.utf16.count
                startOffset = lineOffsets[block.startLine] + openTagLength + 1
            } else {
                startOffset = 0
            }

            mappings.append(BlockMapping(
                blockType: block.type,
                virtualType: virtualType,
                realStartLine: block.startLine,
                realEndLine: block.endLine,
                virtualStartLine: 0,
                contentLineCount: contentLineCount,
                realStartOffset: startOffset,
                lang: block.lang
            ))
        }

        return mappings
    }
}
