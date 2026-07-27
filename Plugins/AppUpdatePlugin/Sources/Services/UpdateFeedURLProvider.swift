import Foundation

/// Lumi's Sparkle `appcast` feed URL collection.
///
/// Ported from `LumiAppKit/Updates/UpdateFeedURLProvider.swift` (v4.19.0).
/// Holds only URL constants and the architecture branch; no AppKit / Sparkle
/// runtime dependency, so it is safe to use in tests.
public enum UpdateFeedURLProvider {

    // MARK: - Primary Feed (owned server)

    /// Primary feed (owned server), branched by the running architecture.
    public static var primary: URL {
        #if arch(arm64)
        return URL(string: "https://s.kuaiyizhi.cn/lumi/appcast-arm64.xml")!
        #else
        return URL(string: "https://s.kuaiyizhi.cn/lumi/appcast-x86_64.xml")!
        #endif
    }

    // MARK: - Fallback Feed (GitHub Release)

    /// Fallback feed (GitHub Release), branched by the running architecture.
    public static var fallback: URL {
        #if arch(arm64)
        return URL(string: "https://github.com/CofficLab/Lumi/releases/latest/download/appcast-arm64.xml")!
        #else
        return URL(string: "https://github.com/CofficLab/Lumi/releases/latest/download/appcast-x86_64.xml")!
        #endif
    }

    // MARK: - Injectable Factory (for tests)

    /// Returns the primary URL for the specified architecture.
    /// Useful for unit tests running on heterogeneous CI machines.
    /// - Parameter architecture: Target architecture identifier (`arm64` or `x86_64`).
    public static func primary(forArchitecture architecture: String) -> URL {
        precondition(
            architecture == "arm64" || architecture == "x86_64",
            "Unsupported architecture: \(architecture)"
        )
        return URL(string: "https://s.kuaiyizhi.cn/lumi/appcast-\(architecture).xml")!
    }

    /// Returns the fallback URL for the specified architecture.
    /// - Parameter architecture: Target architecture identifier (`arm64` or `x86_64`).
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
