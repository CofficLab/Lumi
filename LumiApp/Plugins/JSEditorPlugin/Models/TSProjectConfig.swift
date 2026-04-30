import Foundation

/// 解析后的 tsconfig.json 信息
struct TSProjectConfig: Sendable {
    let baseURL: String?
    let paths: [String: [String]]
    let outDir: String?
    let rootDir: String?
    let jsx: String?
    let strict: Bool?
    let target: String?
    let module: String?
    let moduleResolution: String?

    /// 将 paths 映射转换为 [别名前缀: 真实相对路径前缀]
    /// 例如 `@/*` → `src/*` 变为 `@/` → `src/`
    var aliasMap: [String: String] {
        var result: [String: String] = []
        for (alias, targets) in paths {
            let cleanAlias = alias.replacingOccurrences(of: "/*", with: "")
            guard let firstTarget = targets.first else { continue }
            let cleanTarget = firstTarget.replacingOccurrences(of: "/*", with: "")
            result[cleanAlias] = cleanTarget
        }
        return result
    }
}
