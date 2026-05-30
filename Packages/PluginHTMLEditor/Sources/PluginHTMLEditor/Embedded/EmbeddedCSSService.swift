import Foundation

/// 内嵌 CSS 语言服务适配器
///
/// 将 HTML 中的 <style> 块路由给 CSS LSP 服务。
@MainActor
public final class EmbeddedCSSService {
    /// 单例
    public static let shared = EmbeddedCSSService()

    private var cachedRegions: [HTMLEmbeddedRegion] = []
    private var lastContentHash: Int = 0

    private init() {}

    /// 刷新内嵌 CSS 区域缓存
    public func updateRegions(for content: String) {
        let hash = content.hashValue
        guard hash != lastContentHash else { return }
        lastContentHash = hash
        cachedRegions = EmbeddedRegionScanner.scanRegions(in: content).filter { $0.language == "css" }
    }

    /// 检查给定坐标是否在 CSS 区域内
    public func isInCSSRegion(line: Int, character: Int, sourceLines: [String]) -> Bool {
        let offset = OffsetMapper.absoluteOffset(line: line, character: character, in: sourceLines)
        return cachedRegions.contains { $0.contains(offset) }
    }

    /// 获取给定坐标所在的 CSS 区域
    public func regionAt(line: Int, character: Int, sourceLines: [String]) -> HTMLEmbeddedRegion? {
        let offset = OffsetMapper.absoluteOffset(line: line, character: character, in: sourceLines)
        return cachedRegions.first { $0.contains(offset) }
    }

    /// 将补全坐标转换为虚拟文档坐标
    public func toVirtualCoordinates(line: Int, character: Int, sourceLines: [String]) -> (line: Int, character: Int)? {
        guard let region = regionAt(line: line, character: character, sourceLines: sourceLines) else { return nil }
        return OffsetMapper.toVirtual(line: line, character: character, region: region, sourceLines: sourceLines)
    }
}
