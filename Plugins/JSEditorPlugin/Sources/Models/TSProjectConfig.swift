import Foundation

/// 解析后的 tsconfig.json 信息
public struct TSProjectConfig: Sendable {
    public let baseURL: String?
    public let paths: [String: [String]]
    public let outDir: String?
    public let rootDir: String?
    public let jsx: String?
    public let strict: Bool?
    public let target: String?
    public let module: String?
    public let moduleResolution: String?

    /// 将 paths 映射转换为 [别名前缀: 真实相对路径前缀]
    /// 例如 `@/*` → `src/*` 变为 `@/` → `src/`
    public var aliasMap: [String: String] {
        var result: [String: String] = [:]
        for (alias, targets) in paths {
            let cleanAlias = alias.replacingOccurrences(of: "/*", with: "")
            guard let firstTarget = targets.first else { continue }
            let cleanTarget = firstTarget.replacingOccurrences(of: "/*", with: "")
            result[cleanAlias] = cleanTarget
        }
        return result
    }
}
