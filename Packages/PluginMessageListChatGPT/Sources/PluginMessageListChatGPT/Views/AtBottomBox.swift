import Foundation

/// 「是否在列表底部」的可变盒子。
///
/// - Important: **刻意不实现** `ObservableObject`。
///
///   它被高频的滚动回调写入，若实现 `ObservableObject`，
///   每次写入都会触发 SwiftUI invalidation —— 而滚动回调本身可能由
///   SwiftUI 的布局过程引起，于是形成「写入 → 重绘 → 布局 → 滚动 → 写入」
///   的反馈环，主线程被打满。
///
///   这里只把它当作**跨层传递状态的载体**：滚动层写入，
///   视图层在需要时读取。
final class AtBottomBox {
    /// 当前是否在底部。
    var value: Bool = true

    init(value: Bool = true) {
        self.value = value
    }
}
