import Foundation
import LumiUI

/// V5（ChatGPT）渲染层的动效开关。
///
/// 基准是 V5 方案第 1.4 节：
/// - Reduced Motion 下关闭 shimmer、淡入和位移动画；
/// - 信息本身不能依赖动画表达。
///
/// - Note: 与列表层的 `ChatGPTMotion` 分处不同 module，故各自一份；
///   两个包互不依赖（插件不得依赖插件）。
///   两者的判定语义必须一致。
enum ChatGPTRendererMotion {

    /// 是否允许淡入 / 淡出动画（操作栏显隐）。
    static func allowsFadeAnimation(preference: LumiMotionPreference) -> Bool {
        preference.allowsMotion
    }

    /// 是否允许位移与 shimmer 动画。
    static func allowsShiftAnimation(preference: LumiMotionPreference) -> Bool {
        preference.allowsMotion
    }

    /// 是否允许 shimmer（流式加载微光）。
    static func allowsShimmer(preference: LumiMotionPreference) -> Bool {
        preference.allowsMotion
    }
}
