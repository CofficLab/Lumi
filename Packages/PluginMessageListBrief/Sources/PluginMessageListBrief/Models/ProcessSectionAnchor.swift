import Foundation

/// 过程折叠区内部使用的锚点标识。
///
/// - Important: 必须放在**非泛型**类型里 —— Swift 不允许泛型类型拥有
///   静态存储属性，而这个 id 需要在所有实例间保持稳定
///   （SwiftUI 的 `scrollTo` 靠它定位锚点）。
enum ProcessSectionAnchor {
    /// 底部锚点：贴底跟随时把内层视口滚到这里。
    static let bottomID = "lumi.bounded-process-section.bottom"
}
