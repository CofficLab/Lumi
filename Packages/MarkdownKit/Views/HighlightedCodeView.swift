import SwiftUI

/// 带语法高亮的代码块视图。
/// 通过环境注入的 `CodeHighlightProviding` 获取高亮结果，
/// 无高亮提供者时降级为纯文本渲染。
struct HighlightedCodeView: View {
    let code: String
    let language: String?
    let font: Font
    let preferOuterScroll: Bool
    let highlightProvider: (any CodeHighlightProviding)?

    /// 缓存的高亮结果
    @State private var attributedCode: AttributedString?

    var body: some View {
        Group {
            if let attributedCode {
                codeScrollView(Text(attributedCode))
            } else {
                codeScrollView(Text(verbatim: code))
            }
        }
        .task(id: codeHighlightTaskId) {
            guard let highlightProvider else {
                attributedCode = nil
                return
            }

            attributedCode = await CodeHighlightCache.shared.highlight(
                code: code,
                language: language,
                provider: highlightProvider
            )
        }
    }

    // MARK: - Private

    /// 代码内容滚动容器
    @ViewBuilder
    private func codeScrollView(_ textContent: Text) -> some View {
        if preferOuterScroll {
            HorizontalScrollView {
                textContent
                    .font(font)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .padding(10)
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                textContent
                    .font(font)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .padding(10)
            }
        }
    }

    /// 唯一标识代码+语言组合，变化时重新触发高亮
    private var codeHighlightTaskId: String {
        "\(highlightProvider?.cacheIdentifier ?? ""):\(language ?? ""):\(code)"
    }
}

// MARK: - CodeHighlightCache

private actor CodeHighlightCache {
    static let shared = CodeHighlightCache()

    private struct Entry: Sendable {
        let value: AttributedString?
    }

    private let limit = 128
    private var cache: [String: Entry] = [:]
    private var keys: [String] = []

    func highlight(
        code: String,
        language: String?,
        provider: any CodeHighlightProviding
    ) -> AttributedString? {
        let key = "\(provider.cacheIdentifier):\(language ?? ""):\(code)"
        if let cached = cache[key] {
            return cached.value
        }

        let highlighted = provider.highlight(code: code, language: language)
        cache[key] = Entry(value: highlighted)
        keys.append(key)

        if keys.count > limit {
            let overflow = keys.count - limit
            for key in keys.prefix(overflow) {
                cache.removeValue(forKey: key)
            }
            keys.removeFirst(overflow)
        }

        return highlighted
    }
}
