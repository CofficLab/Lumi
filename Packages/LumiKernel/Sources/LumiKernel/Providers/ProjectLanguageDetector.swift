import Foundation

/// 项目语言检测器：根据项目根目录下的 marker 文件推断 `ProjectEntry.Language`。
public enum ProjectLanguageDetector {
    public static func detect(at path: String) -> ProjectEntry.Language {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return .unknown
        }

        let url = URL(fileURLWithPath: path, isDirectory: true)

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

        let packageJSONPath = url.appendingPathComponent("package.json").path
        if fm.fileExists(atPath: packageJSONPath) {
            return detectJavaScriptVariant(at: packageJSONPath)
        }

        return .unknown
    }

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
