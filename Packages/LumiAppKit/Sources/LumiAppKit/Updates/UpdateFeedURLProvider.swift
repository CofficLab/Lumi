import Foundation

/// Lumi 的 Sparkle `appcast` feed URL 集合
///
/// 拆分自 `LumiApp/Services/UpdateService.swift`，仅承载 URL 常量与架构分支，
/// 不依赖任何 AppKit / Sparkle 运行时，便于单元测试。
public enum UpdateFeedURLProvider {

    // MARK: - Primary Feed（自有服务器）

    /// 主 feed（自有服务器），按运行架构返回对应的 `appcast`。
    public static var primary: URL {
        #if arch(arm64)
        return URL(string: "https://s.kuaiyizhi.cn/lumi/appcast-arm64.xml")!
        #else
        return URL(string: "https://s.kuaiyizhi.cn/lumi/appcast-x86_64.xml")!
        #endif
    }

    // MARK: - Fallback Feed（GitHub Release）

    /// 备用 feed（GitHub Release），按运行架构返回对应的 `appcast`。
    public static var fallback: URL {
        #if arch(arm64)
        return URL(string: "https://github.com/CofficLab/Lumi/releases/latest/download/appcast-arm64.xml")!
        #else
        return URL(string: "https://github.com/CofficLab/Lumi/releases/latest/download/appcast-x86_64.xml")!
        #endif
    }

    // MARK: - 注入式工厂（测试用）

    /// 返回指定架构的 primary URL，便于单元测试在异构 CI 上保持稳定。
    /// - Parameter architecture: 目标架构标识，例如 `arm64` 或 `x86_64`。
    public static func primary(forArchitecture architecture: String) -> URL {
        precondition(
            architecture == "arm64" || architecture == "x86_64",
            "Unsupported architecture: \(architecture)"
        )
        return URL(string: "https://s.kuaiyizhi.cn/lumi/appcast-\(architecture).xml")!
    }

    /// 返回指定架构的 fallback URL，便于单元测试。
    /// - Parameter architecture: 目标架构标识，例如 `arm64` 或 `x86_64`。
    public static func fallback(forArchitecture architecture: String) -> URL {
        precondition(
            architecture == "arm64" || architecture == "x86_64",
            "Unsupported architecture: \(architecture)"
        )
        return URL(
            string: "https://github.com/CofficLab/Lumi/releases/latest/download/appcast-\(architecture).xml"
        )!
    }
}