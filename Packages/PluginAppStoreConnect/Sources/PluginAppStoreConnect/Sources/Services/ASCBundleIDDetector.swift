import Foundation

/// 从项目根目录自动识别 App 的 Bundle ID。
///
/// 识别顺序：
/// 1. Xcode 工程（`.xcodeproj/project.pbxproj`）里的 `PRODUCT_BUNDLE_IDENTIFIER`；
/// 2. Xcode 工程内的 `Info.plist`（含 `$(PRODUCT_BUNDLE_IDENTIFIER)` 占位符时不做推断）；
/// 3. Swift Package 的 `Package.swift` 无法提供 bundle ID，返回 `nil`。
///
/// 纯 SwiftPM 项目没有可发布的 App 目标，因此识别结果为 `nil`，
/// 此时 Chat Toolbar 不展示 ASC 入口。
enum ASCBundleIDDetector {
    /// 从项目根目录识别 Bundle ID。
    ///
    /// - Parameter projectPath: 项目根目录绝对路径。
    /// - Returns: 识别到的 Bundle ID；无法识别时为 `nil`。
    static func detectBundleID(projectPath: String) -> String? {
        let root = URL(fileURLWithPath: projectPath, isDirectory: true)
        let fileManager = FileManager.default

        guard let entries = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard entry.pathExtension == "xcodeproj" else { continue }
            if let bundleID = detectBundleID(inXcodeProjectAt: entry) {
                return bundleID
            }
        }
        return nil
    }

    /// 从单个 `.xcodeproj` 中解析 Bundle ID。
    static func detectBundleID(inXcodeProjectAt projectURL: URL) -> String? {
        let pbxprojURL = projectURL.appendingPathComponent("project.pbxproj")
        guard let contents = try? String(contentsOf: pbxprojURL, encoding: .utf8) else {
            return nil
        }
        return parseBundleID(fromPbxproj: contents)
    }

    /// 从 pbxproj 文本中提取第一个可用的 `PRODUCT_BUNDLE_IDENTIFIER`。
    ///
    /// 跳过含变量占位符（如 `$(PRODUCT_NAME:rfc1034identifier)`）的值——那类值
    /// 依赖 Xcode 的构建设置，静态解析无法确定真实 bundle ID。
    static func parseBundleID(fromPbxproj contents: String) -> String? {
        let pattern = #"PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;\n]+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(contents.startIndex..<contents.endIndex, in: contents)

        var candidates: [String] = []
        for match in regex.matches(in: contents, range: nsRange) {
            guard let range = Range(match.range(at: 1), in: contents) else { continue }
            let raw = String(contents[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = unquote(raw)
            guard !value.isEmpty, !value.contains("$(") else { continue }
            candidates.append(value)
        }

        // 优先取看起来像真实 bundle ID 的值（含点号，且不是测试 target）。
        let preferred = candidates.first { $0.contains(".") && !isTestBundleIdentifier($0) }
        return preferred ?? candidates.first
    }

    /// Xcode 为测试 Target 生成的标准 Bundle ID 后缀（不区分大小写）。
    ///
    /// `uitests` 也以 `tests` 结尾，因此只需匹配 `tests`。
    private static let testTargetSuffix = "tests"

    /// Xcode 追加在 Bundle ID 末尾的构建配置后缀。
    private static let buildConfigurationSuffixes: Set<String> = ["debug", "release"]

    /// 判断一个 Bundle ID 是否属于测试 Target。
    ///
    /// 多 Target 工程里测试 Target 的 Bundle ID 常见形式有 `DemoTests`、
    /// `com.example.DemoTests`、`.Tests` 与 `.UITests`。此前只排除小写的
    /// `.tests` 后缀，于是 `DemoTests` 会被当成主 App，自动绑定拿到的就是
    /// 测试 Target 的 ID（#862）。
    ///
    /// 判定不区分大小写：只看 Bundle ID 的**最后一段**（反向 DNS 的 App 名
    /// 部分），这样 `com.example.DemoTests` 能被识别，而 `com.example.Latest`
    /// 不会因为以 `test` 结尾而被误判。
    static func isTestBundleIdentifier(_ bundleID: String) -> Bool {
        let normalized = bundleID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return false }

        let segments = normalized.split(separator: ".").map(String.init)
        guard let last = segments.last else { return false }

        if last.hasSuffix(testTargetSuffix) {
            return true
        }

        // `com.example.DemoTests.debug`：构建配置后缀之后才是真正的末段。
        if buildConfigurationSuffixes.contains(last), segments.count >= 2 {
            let previous = segments[segments.count - 2]
            if previous.hasSuffix(testTargetSuffix) {
                return true
            }
        }

        return false
    }

    private static func unquote(_ value: String) -> String {
        guard value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 else {
            return value
        }
        return String(value.dropFirst().dropLast())
    }
}
