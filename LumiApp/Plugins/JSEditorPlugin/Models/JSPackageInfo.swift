import Foundation

/// 解析后的 package.json 信息
struct JSPackageInfo: Sendable {
    let name: String
    let version: String
    let scripts: [String: String]
    let dependencies: [String: String]
    let devDependencies: [String: String]
    let engines: [String: String]
    let packageManager: String?

    /// 已识别的脚本分类
    var devScripts: [String] {
        scripts.keys.filter { key in
            let lower = key.lowercased()
            return lower == "dev" || lower == "serve" || lower == "start" || lower.hasSuffix(":dev")
        }.sorted()
    }

    var buildScripts: [String] {
        scripts.keys.filter { key in
            let lower = key.lowercased()
            return lower == "build" || lower == "compile" || lower.hasSuffix(":build")
        }.sorted()
    }

    var testScripts: [String] {
        scripts.keys.filter { key in
            let lower = key.lowercased()
            return lower == "test" || lower.hasSuffix(":test")
        }.sorted()
    }

    var lintScripts: [String] {
        scripts.keys.filter { key in
            let lower = key.lowercased()
            return lower == "lint" || lower == "format" || lower.hasSuffix(":lint")
        }.sorted()
    }

    /// 推断的包管理器
    var inferredPackageManager: PackageManager {
        if let pm = packageManager {
            let prefix = pm.components(separatedBy: "@").first?.lowercased() ?? ""
            if let mgr = PackageManager(rawValue: prefix) {
                return mgr
            }
        }
        return .npm
    }

    /// 推断的测试框架
    var inferredTestFramework: TestFramework? {
        if devDependencies["vitest"] != nil { return .vitest }
        if devDependencies["jest"] != nil { return .jest }
        if devDependencies["@playwright/test"] != nil { return .playwright }
        if devDependencies["mocha"] != nil { return .mocha }
        return nil
    }

    /// 推断的构建工具
    var inferredBuilder: Builder? {
        if devDependencies["vite"] != nil { return .vite }
        if devDependencies["next"] != nil || dependencies["next"] != nil { return .nextjs }
        if devDependencies["webpack"] != nil { return .webpack }
        if devDependencies["esbuild"] != nil { return .esbuild }
        if devDependencies["turbo"] != nil { return .turbo }
        return nil
    }

    /// 推断的前端框架
    var inferredFramework: JSFramework? {
        if dependencies["react"] != nil { return .react }
        if dependencies["vue"] != nil { return .vue }
        if dependencies["@angular/core"] != nil { return .angular }
        if dependencies["svelte"] != nil { return .svelte }
        if dependencies["solid-js"] != nil { return .solid }
        return nil
    }

    enum PackageManager: String, Sendable {
        case npm
        case pnpm
        case yarn
        case bun
    }

    enum TestFramework: String, Sendable {
        case vitest
        case jest
        case playwright
        case mocha
    }

    enum Builder: String, Sendable {
        case vite
        case nextjs
        case webpack
        case esbuild
        case turbo
    }

    enum JSFramework: String, Sendable {
        case react
        case vue
        case angular
        case svelte
        case solid
    }
}
