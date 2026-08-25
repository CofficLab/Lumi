import SwiftUI

/// 带语法高亮的代码块视图。
/// 通过环境注入的 `CodeHighlightProviding` 获取高亮结果，
/// 无高亮提供者时降级为纯文本渲染。
struct HighlightedCodeView: View {
    let code: String
    let language: String?
    let font: Font
    let preferOuterScroll: Bool

    /// 直接从环境中读取高亮提供者，确保 SwiftUI 能正确追踪依赖并响应主题切换。
    @Environment(\.codeHighlightProvider) private var highlightProvider

    /// 缓存的高亮结果
    @State private var attributedCode: AttributedString?

    var body: some View {
        Group {
            if let attributedCode {
                codeScrollView(Text(attributedCode))
            } else if let highlightProvider,
                      let cached = CodeHighlightCache.shared.cached(
                          code: code,
                          language: language,
                          provider: highlightProvider
                      ) {
                // 同步命中(历史行滚回视口的常见情况):首帧即高亮文本,
                // 无"纯文本 → 高亮"的高度跳变,也不占异步任务。
                codeScrollView(Text(cached))
            } else {
                codeScrollView(Text(verbatim: code))
            }
        }
        .task(id: codeHighlightTaskId) {
            guard attributedCode == nil else { return }
            guard let highlightProvider else {
                return
            }

            let highlighted = CodeHighlightCache.shared.highlight(
                code: code,
                language: language,
                provider: highlightProvider
            )
            if attributedCode != highlighted {
                attributedCode = highlighted
            }
        }
    }

    // MARK: - Private

    /// 代码内容滚动容器
    @ViewBuilder
    private func codeScrollView(_ textContent: Text) -> some View {
        if preferOuterScroll {
            HorizontalScrollView(contentFingerprint: ScrollContentFingerprint(
                displayed: attributedCode,
                code: code,
                language: language,
                font: font,
                highlightProviderID: highlightProvider?.cacheIdentifier
            )) {
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

    /// `HorizontalScrollView` 测量缓存的内容指纹：覆盖所有会影响渲染
    /// 结果的输入（异步高亮结果、原始代码、语言、字体、高亮提供者）。
    /// 任一变化都会使测量缓存失效并触发 rootView 更新；
    /// 全部未变时（流式间歇、父视图重求值）复用测量结果（P1）。
    private struct ScrollContentFingerprint: Hashable {
        let displayed: AttributedString?
        let code: String
        let language: String?
        let font: Font
        let highlightProviderID: String?
    }
}

// MARK: - CodeHighlightCache

/// 锁保护的同步缓存(与 `MarkdownBlockCache` 同构):缓存命中可在 `body` 求值
/// 内同步返回,列表滚动使行重新物化时首帧即高亮,不再两阶段布局跳变;
/// miss 时的全量高亮由调用方在 `.task`(后台线程)中完成。
private final class CodeHighlightCache: @unchecked Sendable {
    static let shared = CodeHighlightCache()

    private struct Entry {
        let value: AttributedString?
    }

    private let limit = 512
    private let lock = NSLock()
    private var cache: [String: Entry] = [:]
    private var keys: [String] = []

    /// 只返回缓存命中结果,不触发高亮计算。
    /// 供 `HighlightedCodeView.body` 在视图求值路径上同步调用。
    func cached(
        code: String,
        language: String?,
        provider: any CodeHighlightProviding
    ) -> AttributedString? {
        let key = "\(provider.cacheIdentifier):\(language ?? ""):\(code)"
        lock.lock()
        defer { lock.unlock() }
        return cache[key]?.value
    }

    /// 命中即返回;miss 时同步高亮并写入缓存。
    /// 调用方应在后台线程(如 `.task`)调用,避免长代码高亮阻塞主线程。
    /// 高亮计算在锁外执行,不阻塞并发的缓存查询。
    func highlight(
        code: String,
        language: String?,
        provider: any CodeHighlightProviding
    ) -> AttributedString? {
        let key = "\(provider.cacheIdentifier):\(language ?? ""):\(code)"
        lock.lock()
        let cached = cache[key]
        lock.unlock()
        if let cached {
            return cached.value
        }

        let highlighted = provider.highlight(code: code, language: language)

        lock.lock()
        defer { lock.unlock() }
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
