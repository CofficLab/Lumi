import Foundation
import KitAgentTool

/// 项目与 App Store Connect App 的绑定配置。
///
/// 用户可以在项目里放置 `.lumi/app-store-connect/app.json` 显式声明绑定关系；
/// 未配置时回退到「自动识别 bundle ID」。
struct ASCAppBinding: Equatable {
    /// ASC App 的数字 ID（`/v1/apps/{id}` 的 id）。
    let appID: String?
    /// 目标 App 的 Bundle ID（如 `com.example.app`）。
    let bundleID: String?

    init(appID: String? = nil, bundleID: String? = nil) {
        self.appID = Self.normalize(appID)
        self.bundleID = Self.normalize(bundleID)
    }

    /// 是否至少提供了一种可用于定位 App 的信息。
    var isEmpty: Bool {
        appID == nil && bundleID == nil
    }

    private static func normalize(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

/// 读取项目里的 ASC 绑定配置。
///
/// 配置文件路径固定为 `<project>/.lumi/app-store-connect/app.json`，
/// 与项目配置目录规范一致：写入落在 `.lumi/`，读取兼容历史目录 `.agent/`。
enum ASCAppBindingLoader {
    /// 项目内配置目录名（相对 `.lumi/` 与 `.agent/`）。
    static let componentName = "app-store-connect"
    /// 配置文件名。
    static let fileName = "app.json"

    /// 读取项目配置；文件不存在或解析失败时返回 `nil`（回退到自动识别）。
    ///
    /// - Parameter projectPath: 项目根目录绝对路径。
    static func load(projectPath: String) -> ASCAppBinding? {
        guard let data = readConfigData(projectPath: projectPath),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else {
            return nil
        }
        let binding = ASCAppBinding(
            appID: stringValue(dict["appID"]),
            bundleID: stringValue(dict["bundleID"])
        )
        return binding.isEmpty ? nil : binding
    }

    /// 读取候选配置文件内容（`.lumi/` 优先，`.agent/` 兜底）。
    private static func readConfigData(projectPath: String) -> Data? {
        let candidates = ProjectConfigDirectory.readURLs(
            projectPath: projectPath,
            component: componentName
        )
        .map { $0.appendingPathComponent(fileName) }

        for url in candidates {
            if let data = try? Data(contentsOf: url) {
                return data
            }
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        value as? String
    }
}
