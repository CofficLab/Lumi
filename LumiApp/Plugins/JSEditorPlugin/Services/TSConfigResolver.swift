import Foundation
import MagicKit

/// 解析 tsconfig.json / jsconfig.json，提取路径映射和编译选项
struct TSConfigResolver: SuperLog {
    nonisolated static let emoji = "⚙️"

    /// 从指定目录解析 tsconfig.json（不存在则尝试 jsconfig.json）
    static func resolve(projectPath: String) -> TSProjectConfig? {
        let tsconfigURL = URL(fileURLWithPath: projectPath).appendingPathComponent("tsconfig.json")
        let jsconfigURL = URL(fileURLWithPath: projectPath).appendingPathComponent("jsconfig.json")

        let targetURL: URL
        if FileManager.default.fileExists(atPath: tsconfigURL.path) {
            targetURL = tsconfigURL
        } else if FileManager.default.fileExists(atPath: jsconfigURL.path) {
            targetURL = jsconfigURL
        } else {
            return nil
        }

        return parse(fileURL: targetURL)
    }

    /// 解析指定的 tsconfig/jsconfig 文件
    static func parse(fileURL: URL) -> TSProjectConfig? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let json else { return nil }

            let compilerOptions = json["compilerOptions"] as? [String: Any] ?? [:]

            let baseURL = compilerOptions["baseUrl"] as? String
            let paths = compilerOptions["paths"] as? [String: [String]] ?? [:]
            let outDir = compilerOptions["outDir"] as? String
            let rootDir = compilerOptions["rootDir"] as? String
            let jsx = compilerOptions["jsx"] as? String
            let strict = compilerOptions["strict"] as? Bool
            let target = compilerOptions["target"] as? String
            let module = compilerOptions["module"] as? String
            let moduleResolution = compilerOptions["moduleResolution"] as? String

            return TSProjectConfig(
                baseURL: baseURL,
                paths: paths,
                outDir: outDir,
                rootDir: rootDir,
                jsx: jsx,
                strict: strict,
                target: target,
                module: module,
                moduleResolution: moduleResolution
            )
        } catch {
            return nil
        }
    }
}
