import Foundation
import UniformTypeIdentifiers

/// 把拖放产生的 `NSItemProvider` 解析成本地文件 URL。
///
/// ## 为什么需要这一层
///
/// 输入框（AppKit `NSTextView`）与附件预览（SwiftUI `.onDrop`）走的是**两套**
/// 拖放 API：前者从 `NSPasteboard` 直接读 `NSURL` / `NSString`，后者拿到的是
/// `NSItemProvider`。若各自实现解析，同一次拖放在两处会得到不同判断——
///
/// - Finder 拖文件：pasteboard 里有 `public.file-url`，provider 也能读出 URL；
/// - 编辑器里拖选中的路径：只有纯文本，provider 只能读出字符串。
///
/// 解析策略因此收敛到这里，两处共用，避免「输入框收下了、预览区却收不下」。
///
/// ## 为什么用回调而不是 `async`
///
/// `NSItemProvider` **不是 `Sendable`**：把 provider 捕获进 `Task` 会被
/// Swift 6 的区域隔离检查拒绝（`sending 'providers' risks causing data races`）。
/// 它的数据取回也是回调式的。因此这里保持「在回调里解析、回到主线程交付」
/// 的形状，与 `NSItemProvider` 的实际模型一致。
enum DroppedItemResolver {
    /// 解析全部 provider，把其中的**本地**文件 URL 交回主线程。
    ///
    /// 非文件内容（网页链接、纯文本段落）会被过滤掉：它们没有可读取的本地路径，
    /// 交给下游只会得到一条读不出内容的附件。
    ///
    /// - Parameter completion: 在主线程上调用，参数是解析出的本地文件 URL。
    static func fileURLs(
        from providers: [NSItemProvider],
        completion: @escaping @MainActor ([URL]) -> Void
    ) {
        ConversationInputViewModel.logger.info(
            "[DroppedItemResolver] resolve start, providers=\(providers.count)"
        )
        for (index, provider) in providers.enumerated() {
            ConversationInputViewModel.logger.info(
                "[DroppedItemResolver] provider[\(index)] types=\(provider.registeredTypeIdentifiers)"
            )
        }

        // 每个 provider 一个槽位，结果按 provider 顺序拼接。
        //
        // 用「按索引写槽位」而不是「直接 append」：provider 的取回回调各跑各的
        // 队列，完成顺序不保证与拖放顺序一致。直接 append 会让附件顺序随
        // 取回时序抖动——用户拖三张图，缩略图顺序却随机变化。
        let collector = URLCollector(count: providers.count)
        let group = DispatchGroup()

        for (index, provider) in providers.enumerated() {
            group.enter()
            resolve(provider: provider) { urls in
                collector.set(urls, at: index)
                group.leave()
            }
        }

        group.notify(queue: .main) {
            MainActor.assumeIsolated {
                let urls = collector.snapshot()
                ConversationInputViewModel.logger.info(
                    "[DroppedItemResolver] resolve done, urls=\(urls.map(\.lastPathComponent))"
                )
                completion(urls)
            }
        }
    }

    // MARK: - 单个 provider

    private static func resolve(
        provider: NSItemProvider,
        completion: @escaping @Sendable ([URL]) -> Void
    ) {
        // 首选 file-url 表示：Finder 拖文件走的就是这一路。
        //
        // `canLoadObject(ofClass:)` 的判断不能省：纯文本 provider 同样能被强制
        // 转换成字符串，但把它当 URL 读会得到 `nil` 或一段被误解的路径。
        if provider.canLoadObject(ofClass: URL.self) {
            provider.loadObject(ofClass: URL.self) { object, _ in
                if let url = object, url.isFileURL {
                    completion([url])
                    return
                }
                // 声称能读 URL 却读不出文件 URL（纯文本 provider 被强制转换的
                // 情况）：退回纯文本解析。
                resolvePlainText(provider: provider, completion: completion)
            }
            return
        }

        resolvePlainText(provider: provider, completion: completion)
    }

    /// 取 provider 里的纯文本路径。
    ///
    /// 两种表示都要试，顺序不能反：
    ///
    /// - `public.utf8-plain-text`：内容就是 UTF-8 文本，直接解码；
    /// - `public.plain-text`：内容可能是 `NSKeyedArchiver` 包过的字符串，
    ///   直接解码会失败（不是合法 UTF-8），必须解档。
    ///
    /// 解档走 `unarchivedObject(ofClass:)` 的受限版本，只允许解出 `NSString`，
    /// 不放开任意类，避免把拖放内容当不可信输入做反序列化。
    private static func resolvePlainText(
        provider: NSItemProvider,
        completion: @escaping @Sendable ([URL]) -> Void
    ) {
        let typeIdentifiers = [
            UTType.utf8PlainText.identifier,
            UTType.plainText.identifier,
        ].filter {
            provider.hasItemConformingToTypeIdentifier($0)
        }

        guard !typeIdentifiers.isEmpty else {
            completion([])
            return
        }

        resolvePlainText(
            provider: provider,
            typeIdentifiers: typeIdentifiers,
            index: 0,
            completion: completion
        )
    }

    private static func resolvePlainText(
        provider: NSItemProvider,
        typeIdentifiers: [String],
        index: Int,
        completion: @escaping @Sendable ([URL]) -> Void
    ) {
        // 所有表示都试过了：这一路没有内容可读。
        //
        // 这个判断不能省：`index` 是自增的递归参数，越界会直接崩溃。
        // 「provider 声称有某种表示、实际取不出内容」是真实存在的情形
        // （某些应用的拖放只登记了类型标识却不提供数据）。
        guard typeIdentifiers.indices.contains(index) else {
            completion([])
            return
        }

        let typeIdentifier = typeIdentifiers[index]
        provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
            guard let data else {
                // 这一路表示取不到数据 → 试下一种表示。
                resolvePlainText(
                    provider: provider,
                    typeIdentifiers: typeIdentifiers,
                    index: index + 1,
                    completion: completion
                )
                return
            }

            if let text = String(data: data, encoding: .utf8) {
                completion(urls(fromDroppedText: text))
                return
            }

            if let archived = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
                completion(urls(fromDroppedText: archived as String))
                return
            }

            // 既不是 UTF-8 文本也解不出字符串 → 试下一种表示。
            resolvePlainText(
                provider: provider,
                typeIdentifiers: typeIdentifiers,
                index: index + 1,
                completion: completion
            )
        }
    }

    private static func urls(fromDroppedText text: String) -> [URL] {
        ChatInputEditorRules.fileURLs(fromDroppedString: text)
    }
}

/// 按索引收集各 provider 的解析结果。
///
/// `NSItemProvider` 的取回回调各跑各的队列，会并发写这里，因此用锁保护。
/// 槽位按索引写入，保证最终顺序与拖放顺序一致。
private final class URLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var slots: [[URL]]

    init(count: Int) {
        slots = Array(repeating: [], count: count)
    }

    func set(_ urls: [URL], at index: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard slots.indices.contains(index) else { return }
        slots[index] = urls
    }

    func snapshot() -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        return slots.flatMap { $0 }
    }
}
