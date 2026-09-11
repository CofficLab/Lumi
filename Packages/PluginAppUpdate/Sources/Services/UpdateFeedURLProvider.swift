import Foundation
import ProviderAppUpdate

/// Lumi's Sparkle `appcast` feed URL collection.
///
/// Ported from `LumiAppKit/Updates/UpdateFeedURLProvider.swift` (v4.19.0).
/// Holds only URL constants and the architecture branch; no AppKit / Sparkle
/// runtime dependency, so it is safe to use in tests.
public enum UpdateFeedURLProvider {

    /// Primary feed for the selected release channel and architecture.
    public static func primary(
        for channel: AppUpdateChannel,
        architecture: String
    ) -> URL {
        precondition(
            architecture == "arm64" || architecture == "x86_64",
            "Unsupported architecture: \(architecture)"
        )

        let path = channel == .stable
            ? "appcast-\(architecture).xml"
            : "pre/appcast-pre-\(architecture).xml"
        return URL(string: "https://s.kuaiyizhi.cn/lumi/\(path)")!
    }

    /// Primary feed for the selected channel on the current process architecture.
    public static func primary(for channel: AppUpdateChannel) -> URL {
        primary(for: channel, architecture: currentArchitecture)
    }

    /// GitHub fallback for the selected release channel and architecture.
    /// Preview appcasts are committed to `pre` so fallback never crosses into
    /// the stable channel (GitHub's `latest` URL excludes prereleases).
    public static func fallback(
        for channel: AppUpdateChannel,
        architecture: String
    ) -> URL {
        precondition(
            architecture == "arm64" || architecture == "x86_64",
            "Unsupported architecture: \(architecture)"
        )

        switch channel {
        case .stable:
            return URL(string: "https://github.com/CofficLab/Lumi/releases/latest/download/appcast-\(architecture).xml")!
        case .preview:
            return URL(string: "https://raw.githubusercontent.com/CofficLab/Lumi/pre/appcast-pre-\(architecture).xml")!
        }
    }

    /// GitHub fallback for the selected channel on the current process architecture.
    public static func fallback(for channel: AppUpdateChannel) -> URL {
        fallback(for: channel, architecture: currentArchitecture)
    }

    // MARK: - Primary Feed (owned server)

    /// Primary feed (owned server), branched by the running architecture.
    public static var primary: URL {
        primary(for: .stable)
    }

    // MARK: - Fallback Feed (GitHub Release)

    /// Fallback feed (GitHub Release), branched by the running architecture.
    public static var fallback: URL {
        fallback(for: .stable)
    }

    // MARK: - Injectable Factory (for tests)

    /// Returns the primary URL for the specified architecture.
    /// Useful for unit tests running on heterogeneous CI machines.
    /// - Parameter architecture: Target architecture identifier (`arm64` or `x86_64`).
    public static func primary(forArchitecture architecture: String) -> URL {
        primary(for: .stable, architecture: architecture)
    }

    /// Returns the fallback URL for the specified architecture.
    /// - Parameter architecture: Target architecture identifier (`arm64` or `x86_64`).
    public static func fallback(forArchitecture architecture: String) -> URL {
        fallback(for: .stable, architecture: architecture)
    }

    #if arch(arm64)
    private static let currentArchitecture = "arm64"
    #else
    private static let currentArchitecture = "x86_64"
    #endif

}
