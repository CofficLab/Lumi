import Foundation

/// 项目语言检测器：根据项目根目录下的 marker 文件推断 `ProjectEntry.Language`。
///
/// 供 `ProjectState.setCurrentProjectPath` 在创建条目时调用一次，结果写入
/// `ProjectEntry.language`，供插件在 `agentTools(context:)` 内判断要不要返回工具。
///
/// 设计约束（per-request 契约）：
/// - 本检测**只在项目打开时执行一次**，绝不在 `agentTools(context:)` 内调用——
///   后者必须 O(1) 量级，不能做文件系统 I/O。
/// - 检测失败/无 marker 时返回 `.unknown`，插件自行决定降级策略。
public enum ProjectLanguageDetector {
    /// 扫描给定路径下的 marker 文件，推断项目语言。
    ///
    /// 判定优先级（命中即返回，不继续）：
    /// 1. `Package.swift` → `.swift`
    /// 2. `go.mod` → `.go`
    /// 3. `Cargo.toml` → `.rust`
    /// 4. `pyproject.toml` / `setup.py` → `.python`
    /// 5. `package.json` → 按 `engines`/`dependencies` 区分 `.typescript` / `.javascript`
    /// 6. 其余 → `.unknown`
    ///
    /// - Parameter path: 项目根目录的绝对路径。不存在或非目录时返回 `.unknown`。
    public static func detect(at path: String) -> ProjectEntry.Language {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return .unknown
        }

        let url = URL(fileURLWithPath: path, isDirectory: true)

        // 单文件 marker：存在即判定。
        let singleFileMarkers: [(name: String, language: ProjectEntry.Language)] = [
            ("Package.swift", .swift),
            ("go.mod", .go),
            ("Cargo.toml", .rust),
            ("pyproject.toml", .python),
            ("setup.py", .python),
        ]
        for marker in singleFileMarkers {
            if fm.fileExists(atPath: url.appendingPathComponent(marker.name).path) {
                return marker.language
            }
        }

        // package.json：需进一步看 dependencies 区分 ts/js。
        let packageJSONPath = url.appendingPathComponent("package.json").path
        if fm.fileExists(atPath: packageJSONPath) {
            return detectJavaScriptVariant(at: packageJSONPath)
        }

        return .unknown
    }

    /// 解析 `package.json`，按是否依赖 TypeScript 判定 `.typescript` / `.javascript`。
    ///
    /// 判定规则：`dependencies` 或 `devDependencies` 含 `typescript` / `@types/` /
    /// 任一 `.ts` 专属框架（如 `vite` 用 ts 编写）时归为 `.typescript`，否则 `.javascript`。
    /// 解析失败时降级为 `.javascript`（既然有 package.json，至少是 JS 生态）。
    private static func detectJavaScriptVariant(at packageJSONPath: String) -> ProjectEntry.Language {
        guard let data = FileManager.default.contents(atPath: packageJSONPath),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .javascript
        }

        let dependencies = (root["dependencies"] as? [String: Any]) ?? [:]
        let devDependencies = (root["devDependencies"] as? [String: Any]) ?? [:]
        let allKeys = Array(dependencies.keys) + Array(devDependencies.keys)

        let typescriptIndicators: Set<String> = [
            "typescript", "@types/node", "@types/react", "@types/jest",
        ]
        for key in allKeys where typescriptIndicators.contains(key) || key.hasPrefix("@types/") {
            return .typescript
        }
        return .javascript
    }
}
