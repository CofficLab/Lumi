import Foundation

/// 通过项目根目录的清单文件推断项目类型。
///
/// ## 为什么只看根目录
///
/// 清单文件（`Package.swift` / `package.json` / `Cargo.toml` …）一律位于项目根目录，
/// 根目录的一次 `contentsOfDirectory` 就足以覆盖全部常见工程形态。刻意不递归：
/// 递归会把「打开一个项目」的成本从一次 stat 变成一次全树遍历。
public enum ProjectTypeDetector {
    /// 判定规则表：`(清单文件名, 展示名, SF Symbol)`。
    ///
    /// 顺序即优先级——`labels` 的先后按此表顺序，因此 Swift 会排在 Node 之前。
    private struct Rule {
        let fileNames: [String]
        /// 后缀匹配（例如 `.xcodeproj` / `.csproj`）。
        let suffixes: [String]
        let label: String
        let symbolName: String
    }

    private static let rules: [Rule] = [
        Rule(fileNames: ["Package.swift"], suffixes: [".xcodeproj"], label: "Swift (Xcode / SPM)", symbolName: "swift"),
        Rule(fileNames: ["package.json"], suffixes: [], label: "Node / JavaScript", symbolName: "cube.box"),
        Rule(fileNames: ["Cargo.toml"], suffixes: [], label: "Rust", symbolName: "gearshape.2"),
        Rule(fileNames: ["pyproject.toml", "requirements.txt"], suffixes: [], label: "Python", symbolName: "chevron.left.forwardslash.chevron.right"),
        Rule(fileNames: ["go.mod"], suffixes: [], label: "Go", symbolName: "shippingbox"),
        Rule(fileNames: ["Gemfile"], suffixes: [], label: "Ruby", symbolName: "diamond"),
        Rule(fileNames: ["build.gradle", "build.gradle.kts", "pom.xml"], suffixes: [], label: "Java / Kotlin", symbolName: "cup.and.saucer"),
        Rule(fileNames: [], suffixes: [".sln", ".csproj"], label: "C# / .NET", symbolName: "number"),
        Rule(fileNames: ["composer.json"], suffixes: [], label: "PHP", symbolName: "elephant"),
        Rule(fileNames: ["pubspec.yaml"], suffixes: [], label: "Dart / Flutter", symbolName: "bird"),
        Rule(fileNames: ["mix.exs"], suffixes: [], label: "Elixir", symbolName: "drop"),
        Rule(fileNames: ["build.sbt"], suffixes: [], label: "Scala", symbolName: "square.stack.3d.up"),
        Rule(fileNames: ["stack.yaml"], suffixes: [".cabal"], label: "Haskell", symbolName: "function"),
        Rule(fileNames: ["build.zig"], suffixes: [], label: "Zig", symbolName: "zap"),
        Rule(fileNames: ["DESCRIPTION"], suffixes: [], label: "R", symbolName: "chart.bar"),
    ]

    /// 推断项目根目录的类型。
    ///
    /// 目录不可读时返回 ``ProjectTypeDescriptor/unknown``，不抛错——调用方多半在
    /// 渲染一条提示信息，异常反而会让整块 UI 消失。
    public static func detect(at root: URL) -> ProjectTypeDescriptor {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: root.path) else {
            return .unknown
        }
        return detect(rootEntryNames: names)
    }

    /// 纯函数版本：输入根目录条目名，输出类型描述。
    ///
    /// 与磁盘访问分离，判定规则可以被直接单测覆盖，不必造临时目录。
    public static func detect(rootEntryNames: [String]) -> ProjectTypeDescriptor {
        detect(rootEntryNames: Set(rootEntryNames))
    }

    /// 纯函数版本：输入根目录条目名的集合，输出类型描述。
    public static func detect(rootEntryNames: Set<String>) -> ProjectTypeDescriptor {
        var labels: [String] = []
        var symbolName = "folder"

        for rule in rules {
            let matched = rule.fileNames.contains { rootEntryNames.contains($0) }
                || rule.suffixes.contains { suffix in rootEntryNames.contains { $0.hasSuffix(suffix) } }
            guard matched else { continue }
            labels.append(rule.label)
            if symbolName == "folder" { symbolName = rule.symbolName }
        }

        guard !labels.isEmpty else { return .unknown }
        return ProjectTypeDescriptor(labels: labels, symbolName: symbolName)
    }
}
