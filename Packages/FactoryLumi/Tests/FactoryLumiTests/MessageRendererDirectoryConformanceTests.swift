import Foundation
import Testing

/// 插件消息渲染器目录守卫测试。
///
/// ## 为什么需要它
///
/// Lumi 有两套并行的渲染器机制，插件都可以往里贡献实现：
///
/// | 机制 | 协议 | 粒度 |
/// |------|------|------|
/// | 消息级渲染器 | `MessageRendererItem` | 接管**整条消息** |
/// | 工具调用行渲染器 | `ToolCallRowRenderer` | 替换 assistant 消息内的**单个 ToolCall 行** |
///
/// 历史上这些实现散落在 `Views/`、`Views/Components/`、甚至插件入口文件里。
/// 后果是「这个插件画了一条什么消息」无处可查：新插件作者不知道该把代码放哪，
/// 评审时也看不出一个文件里混了几个类型。
///
/// 规范要求：**所有渲染器类型必须位于名为 `Renderers` 的目录中**
/// （允许 `Renderers/Core/` 这类二级分组）。完整规范见
/// `.lumi/rules/plugin-message-renderer-directory-rules.md`。
///
/// ## 实现方式
///
/// 渲染器是**纯源码结构**，不产出可断言的运行时对象——同一个包里的渲染器
/// 只有在被某个插件注册时才会进入渲染管线，而且注册发生在内核装配期，
/// 单元测试无法覆盖「仓库里所有插件」的组合。
///
/// 因此这里直接审计源码：
///
/// - **判定**：文件里出现 `MessageRendererItem(` 构造，或声明遵循
///   `ToolCallRowRenderer` 协议，即认为该文件是渲染器文件；
/// - **断言**：该文件的祖先目录链里必须存在名为 `Renderers` 的目录。
///
/// 扫描范围是 `Packages/**/Sources/**`，覆盖全部 SPM 插件包。
@Suite("Message Renderer Directory Conformance")
struct MessageRendererDirectoryConformanceTests {

    // MARK: - 基准常量

    /// 渲染器的归属目录名。
    private static let rendererDirectoryName = "Renderers"

    /// 判定「这是渲染器文件」的两个特征串。
    ///
    /// - `MessageRendererItem(`：消息级渲染器的构造调用。
    /// - `ToolCallRowRenderer`：工具调用行渲染器的协议声明。
    ///
    /// 两者都**排除** `ProviderMessageRendering` 自身——那里定义协议，
    /// 不是插件贡献的实现。
    private static let rendererMarkers = [
        "MessageRendererItem(",
        ": ToolCallRowRenderer",
        ", ToolCallRowRenderer",
    ]

    // MARK: - 用例

    /// 所有渲染器文件都必须位于 `Renderers/` 目录下。
    @Test("渲染器实现必须放在 Renderers/ 目录")
    func renderersLiveInRenderersDirectory() throws {
        let violations = try Self.violations()
        #expect(
            violations.isEmpty,
            """
            以下文件包含渲染器实现，但不在 `Renderers/` 目录下：

            \(violations.joined(separator: "\n"))

            规范见 `.lumi/rules/plugin-message-renderer-directory-rules.md`：
            把渲染器类型移入插件包的 `Renderers/` 目录（可再分二级子目录），
            卡片视图留在 `Views/`，载荷模型留在 `Models/`。
            """
        )
    }

    /// 守卫本身要能工作：确认扫描确实发现了已知的渲染器文件。
    ///
    /// 没有这条断言的话，一次「扫描逻辑写错导致永远扫不到任何文件」的
    /// 改动会让上面的用例变成永远为真的空测试——红灯失灵。
    @Test("扫描能发现已知的渲染器文件")
    func scannerFindsKnownRenderers() throws {
        let found = try Self.rendererFiles()
        let paths = Set(found.map(\.relativePath))
        #expect(!paths.isEmpty, "扫描未发现任何渲染器文件，判定逻辑可能已失效")
        #expect(
            paths.contains { $0.hasSuffix("Renderers/FinderCardRenderer.swift") },
            "扫描未发现 PluginFinder 的渲染器，判定逻辑可能已失效"
        )
    }

    /// 渲染器文件与其目录名一致，便于按名定位。
    @Test("渲染器文件名与主类型名一致")
    func rendererFileNameMatchesTypeName() throws {
        let mismatches = try Self.rendererFiles().compactMap { file -> String? in
            // 文件名去掉 `.swift` 后应与文件里声明的类型名一致。
            let expected = file.url.deletingPathExtension().lastPathComponent
            let source = try String(contentsOf: file.url, encoding: .utf8)
            let typeNames = Self.declaredTypeNames(in: source)
            guard !typeNames.isEmpty else { return nil }
            return typeNames.contains(expected) ? nil : file.relativePath
        }
        #expect(
            mismatches.isEmpty,
            """
            以下渲染器文件的文件名与其中的类型名不一致：

            \(mismatches.joined(separator: "\n"))
            """
        )
    }

    // MARK: - 扫描实现

    /// 扫描出仓库中所有渲染器文件。
    private static func rendererFiles() throws -> [File] {
        let root = try repositoryRoot()
        let packagesRoot = root.appendingPathComponent("Packages")
        let files = try swiftFiles(under: packagesRoot)
        return files.compactMap { url in
            let source = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            guard isRendererSource(source) else { return nil }
            return File(url: url, relativePath: Self.relativePath(of: url, from: root))
        }
    }

    /// 收集所有违规文件（渲染器文件不在 `Renderers/` 目录下）。
    private static func violations() throws -> [String] {
        try rendererFiles()
            .filter { file in
                !file.url.pathComponents.contains(rendererDirectoryName)
            }
            .map(\.relativePath)
            .sorted()
    }

    /// 判断一个源码文件是否是渲染器文件。
    private static func isRendererSource(_ source: String) -> Bool {
        // `ProviderMessageRendering` 定义协议本身，不是插件贡献的实现。
        if source.contains("public protocol ToolCallRowRenderer") { return false }
        return rendererMarkers.contains { source.contains($0) }
    }

    /// 提取源码里声明的类型名（struct / class / enum / actor）。
    private static func declaredTypeNames(in source: String) -> Set<String> {
        let pattern = #"(?:struct|class|enum|actor)\s+([A-Z][A-Za-z0-9]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        var names: Set<String> = []
        for match in regex.matches(in: source, range: nsRange) {
            guard let range = Range(match.range(at: 1), in: source) else { continue }
            names.insert(String(source[range]))
        }
        return names
    }

    /// 收集目录下的全部 Swift 文件（跳过构建产物）。
    private static func swiftFiles(under root: URL) throws -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            // 跳过构建产物目录。
            if fileURL.pathComponents.contains(".build") { continue }
            // 跳过测试目录：测试里的桩渲染器（TestDoubles）不归本规范管。
            if fileURL.pathComponents.contains("Tests") { continue }
            files.append(fileURL)
        }
        return files
    }

    /// 从本测试文件所在位置向上找仓库根（含 `Lumi.xcodeproj` 的目录）。
    private static func repositoryRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            if FileManager.default.fileExists(
                atPath: url.appendingPathComponent("Lumi.xcodeproj").path
            ) {
                return url
            }
            url.deleteLastPathComponent()
        }
        throw RepositoryRootNotFoundError()
    }

    /// 生成相对仓库根的路径，用于断言输出。
    private static func relativePath(of url: URL, from root: URL) -> String {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard url.path.hasPrefix(rootPath) else { return url.path }
        return String(url.path.dropFirst(rootPath.count))
    }

    /// 渲染器文件（URL + 相对路径）。
    private struct File {
        let url: URL
        let relativePath: String
    }

    private struct RepositoryRootNotFoundError: Error {}
}
