import AppKit

/// UI 测试期间的剪贴板快照守卫。
///
/// ## 为什么需要它
///
/// UI 测试用「剪贴板 + ⌘V」代替 `typeText` 写入文本（原因见
/// `LumiUITestCase` 的实测对照表），而 `NSPasteboard.general` 是**全机器共享**
/// 的系统资源：测试写入的探针文本会直接覆盖用户自己复制的内容，
/// 并且一直留到用户手动再复制一次为止。
///
/// 对开发者日常的代价很实在——跑完一轮 UI 测试，剪贴板里躺着
/// `UI Testing Send Button Probe` 这种字符串，粘贴到别处才发现。
///
/// ## 为什么快照放在粘贴函数内部
///
/// 不是在 `setUpWithError` 存、`tearDownWithError` 还原：
/// 绝大多数用例的 `setUpWithError` 覆写后**不调用 `super`**（见各测试文件），
/// 基类钩子不会执行，放那里等于没放。
///
/// `paste()` 自身是唯一真正写剪贴板的地方，且它生命周期极短——
/// 写入 → `⌘V` → 一次 `sleep` 兜底事件送达。文本在 `⌘V` 被处理的那一刻
/// 就已复制进控件，此后剪贴板内容不再被需要，因此**函数返回即可还原**，
/// 既保证 ⌘V 拿得到内容，又把污染窗口压到最小。
///
/// - Important: 还原必须放在 `defer` 里（而非 `⌘V` 之后立刻同步执行），
///   因为 `⌘V` 的合成按键是异步投递的；少了尾部的 `sleep` 会偶发粘不上。
enum UITestClipboard {
    /// 通用剪贴板在某一时刻的内容快照。
    struct Snapshot {
        /// 按类型保存的原始数据。
        ///
        /// 用 `[NSPasteboard.PasteboardType: Data]` 而非只存字符串：
        /// 用户复制的是图片、文件或富文本时，只保存字符串会把其余类型
        /// 一起丢掉，还原后剪贴板就被降级成了纯文本。
        ///
        /// - Note: 保持内部可见而非 `private`：`UITestClipboard.restore`
        ///   在结构体外访问它，Swift 的 `private` 不跨类型。
        let items: [NSPasteboard.PasteboardType: Data]

        /// 快照是否为空（还原时等价于「清空剪贴板」）。
        var isEmpty: Bool { items.isEmpty }

        init(items: [NSPasteboard.PasteboardType: Data]) {
            self.items = items
        }
    }

    /// 捕获当前通用剪贴板的内容。
    static func snapshot() -> Snapshot {
        let pasteboard = NSPasteboard.general
        var items: [NSPasteboard.PasteboardType: Data] = [:]
        for type in pasteboard.types ?? [] {
            if let data = pasteboard.data(forType: type) {
                items[type] = data
            }
        }
        return Snapshot(items: items)
    }

    /// 把通用剪贴板恢复为给定快照。
    static func restore(_ snapshot: Snapshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        for (type, data) in snapshot.items {
            pasteboard.setData(data, forType: type)
        }
    }

    /// 在闭包执行期间保护剪贴板：进入前快照，退出前还原。
    ///
    /// 用 `defer` 保证即使闭包中途抛出错误，剪贴板也会被还原。
    static func preserving<T>(_ body: () throws -> T) rethrows -> T {
        let snapshot = snapshot()
        defer { restore(snapshot) }
        return try body()
    }
}
