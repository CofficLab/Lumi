/// 可变布尔盒子，刻意不实现 `ObservableObject`。
///
/// 消息列表视图（V1 / V2 / V3）用它持有「是否在列表底部」这一滚动判定，使偏好/观察
/// 回调写入它时**不会**进入 SwiftUI 的 invalidation 图 —— 这是切断底部锚点
/// Preference 反馈环（`@State` → body 重建 → 偏好重报 → 活锁）的关键。
///
/// 由 `ScrollViewBottomTracker`（观察 NSScrollView）翻转，由各消息列表视图读取。
@MainActor
final class AtBottomBox {
    var value: Bool = true
}
