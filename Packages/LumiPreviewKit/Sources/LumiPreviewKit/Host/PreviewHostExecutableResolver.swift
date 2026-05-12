import Foundation

/// Resolves the `LumiPreviewHostApp` executable used by live and image previews.
public enum PreviewHostExecutableResolver {
    /// Environment variable that can override bundled host discovery.
    public static let environmentOverrideKey = "LUMI_PREVIEW_HOST_EXECUTABLE"

    /// Resolve the preview host executable from an explicit environment override or known bundle locations.
    public static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> URL? {
        if let explicitPath = environment[environmentOverrideKey],
           !explicitPath.isEmpty {
            let url = URL(fileURLWithPath: explicitPath)
            if fileManager.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        return candidates(in: bundle).first {
            fileManager.isExecutableFile(atPath: $0.path)
        }
    }

    /// Candidate locations in priority order.
    public static func candidates(in bundle: Bundle = .main) -> [URL] {
        [
            bundle.bundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("Helpers", isDirectory: true)
                .appendingPathComponent("LumiPreviewHostApp"),
            bundle.bundleURL
                .appendingPathComponent("Contents", isDirectory: true)
                .appendingPathComponent("MacOS", isDirectory: true)
                .appendingPathComponent("LumiPreviewHostApp"),
            bundle.resourceURL?
                .appendingPathComponent("LumiPreviewHostApp")
        ].compactMap { $0 }
    }
}
