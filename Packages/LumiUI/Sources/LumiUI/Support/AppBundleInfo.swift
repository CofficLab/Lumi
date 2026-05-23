import Foundation

/// Bundle metadata for settings / about surfaces.
public struct AppBundleInfo: Sendable, Equatable {
    public let name: String
    public let version: String?
    public let build: String?
    public let bundleIdentifier: String
    public let description: String?

    public init(bundle: Bundle = .main) {
        self.name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "App"
        self.version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        self.build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        self.bundleIdentifier = bundle.bundleIdentifier ?? "com.example.app"
        self.description = bundle.object(forInfoDictionaryKey: "CFBundleGetInfoString") as? String
    }
}
