import Foundation

/// 持久化「当前选中的模型」所用的偏好域。
///
/// ## 为什么需要它
///
/// `DefaultLLMManager` 与 `CustomLLMManager` 原本直接读写
/// `UserDefaults.standard`——那是**用户级全局状态**。测试若不隔离：
///
/// - 会读写开发者本机的真实偏好（污染，且可能改掉用户正在用的模型选择）；
/// - 用户残留的选中值会让断言随机失败——失败点漂移，极难复现。
///
/// ## 用法
///
/// 生产环境用 `.standard`；测试注入 `UserDefaults(suiteName:)` 的隔离实例：
///
/// ```swift
/// let defaults = UserDefaults(suiteName: "com.coffic.lumi.test.\(UUID().uuidString)")
/// DefaultLLMManager.userDefaults = defaults
/// defer { DefaultLLMManager.userDefaults = .standard }
/// ```
///
/// - Note: `KitTestSupport.IsolatedUserDefaults` 提供了现成的隔离实现。
public enum LLMManagerUserDefaults {

    /// 当前使用的偏好域。
    ///
    /// - Important: 静态可变状态；`LLMManagerProviding` 本身也是进程级单例，
    ///   两者语义一致。测试必须在自己的用例内设置并恢复。
    nonisolated(unsafe) public static var current: UserDefaults = .standard
}
