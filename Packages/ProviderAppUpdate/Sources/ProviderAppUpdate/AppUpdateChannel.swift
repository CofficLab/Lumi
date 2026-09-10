import Foundation

/// The release track used by the direct-distribution updater.
public enum AppUpdateChannel: String, CaseIterable, Codable, Hashable, Sendable {
    /// Stable builds published from `main`.
    case stable
    /// Preview builds published from `pre`; they may contain unfinished changes.
    case preview

    public static let userDefaultsKey = "com.coffic.lumi.appUpdateChannel"
}

/// Host-owned update settings consumed by the General settings plugin.
///
/// The contract intentionally contains no Sparkle or AppKit types. The host
/// updater owns persistence and feed selection; settings only renders and
/// changes the selected channel through this provider.
@MainActor
public protocol AppUpdateChannelProviding: AnyObject {
    var channel: AppUpdateChannel { get }
    func setChannel(_ channel: AppUpdateChannel)
}
