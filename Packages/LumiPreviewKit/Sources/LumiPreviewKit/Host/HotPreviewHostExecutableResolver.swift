import Foundation

public extension LumiPreviewFacade {
    /// Resolves the `LumiHotPreviewHostApp` executable.
    enum HotPreviewHostExecutableResolver {
        public static let environmentOverrideKey = "LUMI_HOT_PREVIEW_HOST_EXECUTABLE"

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

        public static func candidates(in bundle: Bundle = .main) -> [URL] {
            [
                bundle.bundleURL
                    .appendingPathComponent("Contents", isDirectory: true)
                    .appendingPathComponent("Helpers", isDirectory: true)
                    .appendingPathComponent("LumiHotPreviewHostApp"),
                bundle.bundleURL
                    .appendingPathComponent("Contents", isDirectory: true)
                    .appendingPathComponent("MacOS", isDirectory: true)
                    .appendingPathComponent("LumiHotPreviewHostApp"),
                bundle.resourceURL?
                    .appendingPathComponent("LumiHotPreviewHostApp")
            ].compactMap { $0 }
        }
    }
}
