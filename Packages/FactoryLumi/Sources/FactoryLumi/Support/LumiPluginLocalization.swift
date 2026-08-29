import Foundation
import KitLocalization

private final class FactoryLumiBundleFinder {}

/// FactoryLumi 的运行时本地化。
///
/// 委托 `LumiLocalization` 按插件 bundle 的 Localizable 表查找。
public enum LumiPluginLocalization {
    public static let bundle: Bundle = {
        let bundleName = "FactoryLumi_FactoryLumi"
        let overrideURLs = [
            ProcessInfo.processInfo.environment["PACKAGE_RESOURCE_BUNDLE_PATH"],
            ProcessInfo.processInfo.environment["PACKAGE_RESOURCE_BUNDLE_URL"],
        ].compactMap { path in
            path.map { URL(fileURLWithPath: $0) }
        }
        let candidates = overrideURLs + [
            Bundle.main.resourceURL,
            Bundle(for: FactoryLumiBundleFinder.self).resourceURL,
            Bundle.main.bundleURL,
        ].compactMap { $0 }

        for candidate in candidates {
            let bundleURL = candidate.appendingPathComponent(bundleName + ".bundle")
            if let bundle = Bundle(url: bundleURL) {
                return bundle
            }
        }

        fatalError("unable to find bundle named \(bundleName)")
    }()

    public static func string(_ key: String, bundle: Bundle, locale: Locale = .current) -> String {
        LumiLocalization.string(key, bundle: bundle, locale: locale)
    }
}
