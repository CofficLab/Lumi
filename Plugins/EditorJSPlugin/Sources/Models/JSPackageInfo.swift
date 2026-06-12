import Foundation

/// 解析后的 package.json 信息
public struct JSPackageInfo: Sendable {
    public let name: String
    public let version: String
    public let scripts: [String: String]
    public let dependencies: [String: String]
    public let devDependencies: [String: String]
    public let peerDependencies: [String: String]
    public let optionalDependencies: [String: String]
    public let engines: [String: String]
    public let packageManager: String?

    private var allDependencies: [String: String] {
        dependencies
            .merging(devDependencies) { current, _ in current }
            .merging(peerDependencies) { current, _ in current }
            .merging(optionalDependencies) { current, _ in current }
    }

    public func hasDependency(_ name: String) -> Bool {
        allDependencies[name] != nil
    }

    /// 已识别的脚本分类
    public var devScripts: [String] {
        scripts.keys.filter { key in
            let lower = key.lowercased()
            return lower == "dev" || lower == "serve" || lower == "start" || lower.hasSuffix(":dev")
        }.sorted()
    }

    public var buildScripts: [String] {
        scripts.keys.filter { key in
            let lower = key.lowercased()
            return lower == "build" || lower == "compile" || lower.hasSuffix(":build")
        }.sorted()
    }

    public var testScripts: [String] {
        scripts.keys.filter { key in
            let lower = key.lowercased()
            return lower == "test" || lower.hasSuffix(":test")
        }.sorted()
    }

    public var lintScripts: [String] {
        scripts.keys.filter { key in
            let lower = key.lowercased()
            return lower == "lint" || lower == "format" || lower.hasSuffix(":lint")
        }.sorted()
    }

    /// 推断的包管理器
    public var inferredPackageManager: PackageManager {
        if let pm = packageManager {
            let prefix = pm.components(separatedBy: "@").first?.lowercased() ?? ""
            if let mgr = PackageManager(rawValue: prefix) {
                return mgr
            }
        }
        return .npm
    }

    /// 推断的测试框架
    public var inferredTestFramework: TestFramework? {
        if allDependencies["vitest"] != nil { return .vitest }
        if allDependencies["jest"] != nil { return .jest }
        if allDependencies["@playwright/test"] != nil { return .playwright }
        if allDependencies["mocha"] != nil { return .mocha }
        return nil
    }

    /// 推断的构建工具
    public var inferredBuilder: Builder? {
        if allDependencies["vite"] != nil { return .vite }
        if allDependencies["next"] != nil { return .nextjs }
        if allDependencies["webpack"] != nil { return .webpack }
        if allDependencies["esbuild"] != nil { return .esbuild }
        if allDependencies["turbo"] != nil { return .turbo }
        return nil
    }

    /// 推断的前端框架
    public var inferredFramework: JSFramework? {
        if allDependencies["react"] != nil { return .react }
        if allDependencies["vue"] != nil { return .vue }
        if allDependencies["@angular/core"] != nil { return .angular }
        if allDependencies["svelte"] != nil { return .svelte }
        if allDependencies["solid-js"] != nil { return .solid }
        return nil
    }

    public enum PackageManager: String, Sendable {
        case npm
        case pnpm
        case yarn
        case bun
    }

    public enum TestFramework: String, Sendable {
        case vitest
        case jest
        case playwright
        case mocha
    }

    public enum Builder: String, Sendable {
        case vite
        case nextjs
        case webpack
        case esbuild
        case turbo
    }

    public enum JSFramework: String, Sendable {
        case react
        case vue
        case angular
        case svelte
        case solid
    }
}
