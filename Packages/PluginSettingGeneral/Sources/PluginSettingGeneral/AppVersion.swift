import Foundation

/// App 版本信息
///
/// 从主 App 的 `Info.plist` 读取版本号；在无 App bundle 的上下文
/// （如单元测试）中可通过 `current` 的自定义实现替换。
public enum AppVersion {
    /// 读取当前 App 版本（`CFBundleShortVersionString` + `CFBundleVersion`）。
    ///
    /// 无 Info.plist 或缺失版本 key 时返回 nil。
    public static var current: String? {
        guard let info = Bundle.main.infoDictionary else { return nil }
        let short = info["CFBundleShortVersionString"] as? String
        let build = info["CFBundleVersion"] as? String
        switch (short, build) {
        case let (short?, build?):
            return "\(short) (\(build))"
        case let (short?, nil):
            return short
        case let (nil, build?):
            return build
        case (nil, nil):
            return nil
        }
    }
}
