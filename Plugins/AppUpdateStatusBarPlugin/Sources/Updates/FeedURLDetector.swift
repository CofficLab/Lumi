import Foundation

/// Detects the feed URL from the app bundle's `Info.plist`.
///
/// Reads `SUFeedURL` (Sparkle) or `LumiFeedURL` (custom).
enum FeedURLDetector {
    /// Detect the feed URL from the app bundle.
    /// Returns `nil` if the key is not present or the URL is malformed.
    static func detectFeedURL(from bundle: Bundle = .main) -> URL? {
        // Try SUFeedURL first (Sparkle convention)
        if let urlString = bundle.infoDictionary?["SUFeedURL"] as? String,
           let url = URL(string: urlString) {
            return url
        }

        // Try LumiFeedURL (custom key)
        if let urlString = bundle.infoDictionary?["LumiFeedURL"] as? String,
           let url = URL(string: urlString) {
            return url
        }

        return nil
    }
}
