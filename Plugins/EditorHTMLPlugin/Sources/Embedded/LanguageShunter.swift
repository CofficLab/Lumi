import Foundation

/// 语言上下文路由器
///
/// 根据光标位置智能切换语言上下文：
/// - HTML 区域 → HTML 补全/诊断
/// - `<style>` 区域 → CSS 补全/诊断
/// - `<script>` 区域 → JS/TS 补全/诊断
///
/// 这是 HTML 多语言支持的核心协调器。
@MainActor
final class LanguageShunter {
    /// 语言上下文
    enum Context {
        case html
        case css
        case javascript
        case typescript
    }

    /// 缓存的内嵌区域
    private var embeddedRegions: [HTMLEmbeddedRegion] = []

    /// 刷新内嵌区域
    func update(content: String) {
        embeddedRegions = EmbeddedRegionScanner.scanRegions(in: content)
    }

    /// 获取光标位置的语言上下文
    func contextAt(line: Int, character: Int, sourceLines: [String]) -> Context {
        let offset = OffsetMapper.absoluteOffset(line: line, character: character, in: sourceLines)

        if let region = embeddedRegions.first(where: { $0.contains(offset) }) {
            switch region.language {
            case "css":
                return .css
            case "javascript":
                return .javascript
            case "typescript":
                return .typescript
            default:
                return .html
            }
        }

        return .html
    }

    /// 判断是否应该禁用 HTML Emmet（在内嵌语言区域内）
    func shouldDisableHTMLEmmit(at line: Int, character: Int, sourceLines: [String]) -> Bool {
        let context = contextAt(line: line, character: character, sourceLines: sourceLines)
        switch context {
        case .html:
            return false
        case .css, .javascript, .typescript:
            return true
        }
    }

    /// 获取当前区域的内嵌语言列表
    func embeddedLanguages() -> [String] {
        return embeddedRegions.map(\.language).uniqued()
    }

    /// 获取所有内嵌区域
    func allRegions() -> [HTMLEmbeddedRegion] {
        return embeddedRegions
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
