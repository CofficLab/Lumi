import Foundation

/// 内嵌 JS/TS 语言服务适配器
///
/// 将 HTML 中的 <script> 块路由给 JS/TS LSP 服务。
@MainActor
final class EmbeddedJSService {
    /// 单例
    static let shared = EmbeddedJSService()

    private var cachedRegions: [HTMLEmbeddedRegion] = []
    private var lastContentHash: Int = 0

    private init() {}

    /// 刷新内嵌 JS/TS 区域缓存
    func updateRegions(for content: String) {
        let hash = content.hashValue
        guard hash != lastContentHash else { return }
        lastContentHash = hash
        cachedRegions = EmbeddedRegionScanner.scanRegions(in: content).filter {
            $0.language == "javascript" || $0.language == "typescript"
        }
    }

    /// 检查给定坐标是否在 JS/TS 区域内
    func isInJSRegion(line: Int, character: Int, sourceLines: [String]) -> Bool {
        let offset = OffsetMapper.absoluteOffset(line: line, character: character, in: sourceLines)
        return cachedRegions.contains { $0.contains(offset) }
    }

    /// 获取给定坐标所在的 JS/TS 区域
    func regionAt(line: Int, character: Int, sourceLines: [String]) -> HTMLEmbeddedRegion? {
        let offset = OffsetMapper.absoluteOffset(line: line, character: character, in: sourceLines)
        return cachedRegions.first { $0.contains(offset) }
    }

    /// 获取区域的语言类型
    func languageAt(line: Int, character: Int, sourceLines: [String]) -> String? {
        return regionAt(line: line, character: character, sourceLines: sourceLines)?.language
    }
}
