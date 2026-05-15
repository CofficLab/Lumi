import Foundation
import os

/// Vue 版本检测器
///
/// 通过读取项目 package.json 检测 Vue 版本 (Vue 2 / Vue 3)，
/// 供 Volar 服务管理器决定启动哪个 Language Server。
struct VueVersionDetector: Sendable {
    nonisolated static let emoji = "🔍"

    /// 检测结果
    enum VueVersion: String, Sendable {
        case vue2
        case vue3
        case unknown

        /// 对应的 Language Server 包名
        var languageServerPackage: String {
            switch self {
            case .vue2: return "@vue/vue2-language-server"
            case .vue3, .unknown: return "@vue/language-server"
            }
        }

        /// 对应的 Language Server 二进制路径 (相对于 node_modules)
        var languageServerBinary: String {
            switch self {
            case .vue2: return "node_modules/@vue/vue2-language-server/bin/vue2-language-server.js"
            case .vue3, .unknown: return "node_modules/@vue/language-server/bin/vue-language-server.js"
            }
        }
    }

    /// 在指定项目路径下检测 Vue 版本
    ///
    /// - Parameter projectPath: 项目根目录路径
    /// - Returns: 检测到的 Vue 版本，无法确定时返回 .unknown
    static func detect(at projectPath: String) -> VueVersion {
        let packageJSONPath = (projectPath as NSString).appendingPathComponent("package.json")

        guard let data = FileManager.default.contents(atPath: packageJSONPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .unknown
        }

        let dependencies = json["dependencies"] as? [String: String] ?? [:]
        let devDependencies = json["devDependencies"] as? [String: String] ?? [:]

        let vueVersion = dependencies["vue"] ?? devDependencies["vue"]

        guard let version = vueVersion else { return .unknown }

        if version.hasPrefix("^2") || version.hasPrefix("~2") || version.hasPrefix("2") {
            return .vue2
        }

        // 默认为 Vue 3（包括 ^3, ~3, latest, next 等）
        return .vue3
    }
}
