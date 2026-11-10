import Foundation
import LumiUI

/// V5（ChatGPT）的动效开关。
///
/// 基准是 V5 方案第 1.4 节：
/// - Reduced Motion 下关闭 shimmer、淡入和位移动画；
/// - 信息本身不能依赖动画表达 —— 也就是说，
///   关闭动画后用户仍能从**静态状态**读出同样的信息。
///
/// - Note: 判定逻辑是**纯函数**，因此可以单测；
///   View 层通过 `LumiMotionPreferenceReader` 读到系统与应用的偏好后传入。
enum ChatGPTMotion {

    /// 是否允许位移动画（元素位移、缩放）。
    static func allowsShiftAnimation(preference: LumiMotionPreference) -> Bool {
        preference.allowsMotion
    }

    /// 是否允许淡入 / 淡出动画。
    static func allowsFadeAnimation(preference: LumiMotionPreference) -> Bool {
        preference.allowsMotion
    }

    /// 是否允许 shimmer（流式加载微光）。
    ///
    /// - Important: shimmer 是**纯装饰**，关闭后信息不丢失，
    ///   因此 Reduced Motion 下必须关闭。
    static func allowsShimmer(preference: LumiMotionPreference) -> Bool {
        preference.allowsMotion
    }
}
