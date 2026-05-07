import Foundation
import MagicKit

/// 解析 package.json，提取项目画像
struct PackageJSONParser: SuperLog {
    nonisolated static let emoji = "📦"

    /// 从指定目录解析 package.json
    static func parse(projectPath: String) -> JSPackageInfo? {
        let url = URL(fileURLWithPath: projectPath).appendingPathComponent("package.json")
        return parse(fileURL: url)
    }

    /// 从文件 URL 解析
    static func parse(fileURL: URL) -> JSPackageInfo? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json else { return nil }

            let name = json["name"] as? String ?? ""
            let version = json["version"] as? String ?? ""
            let scripts = json["scripts"] as? [String: String] ?? [:]
            let dependencies = json["dependencies"] as? [String: String] ?? [:]
            let devDependencies = json["devDependencies"] as? [String: String] ?? [:]
            let engines = json["engines"] as? [String: String] ?? [:]
            let packageManager = json["packageManager"] as? String

            return JSPackageInfo(
                name: name,
                version: version,
                scripts: scripts,
                dependencies: dependencies,
                devDependencies: devDependencies,
                engines: engines,
                packageManager: packageManager
            )
        } catch {
            return nil
        }
    }
}
