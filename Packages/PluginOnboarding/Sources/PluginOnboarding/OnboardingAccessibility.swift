import Foundation

/// 新手引导的可访问性标识符。
///
/// ## 为什么需要集中在这里
///
/// 引导的按钮文案随语言变化（`Continue` / `Finish` / `Skip` 及其各语言译文）。
/// UI 测试若按文案点击，就只能写死某一种语言 —— 中文用例必然点不到按钮，
/// 引导浮层留在窗口上，后续「点设置按钮」「点发送按钮」都会落在浮层上，
/// 失败现象却表现为「设置窗口没出现」「弹窗没出现」，与真实原因毫无关联。
///
/// 标识符不随语言变化，是这里唯一稳定的判据。
public enum OnboardingAccessibility {
    /// 底部主按钮：非末页是 `Continue`，末页是 `Finish`（同一个 Button）。
    public static let primaryButton = "lumi.onboarding.primary"

    /// 顶部的 `Skip` 按钮（仅非末页出现）。
    public static let skipButton = "lumi.onboarding.skip"
}
