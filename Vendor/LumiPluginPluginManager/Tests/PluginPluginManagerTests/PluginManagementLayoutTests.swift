import Foundation
import Testing

/// 插件管理页的布局守卫。
///
/// 这套断言原先由 Lumi 仓的 `SettingsLayoutConformanceTests` 承担。插件管理包
/// 迁到独立远程包后，源码不再位于 Lumi 仓的 `Packages/` 下，仓库级审计会静默
/// 跳过该页（找不到源文件即 `continue`），布局约束就会失去守卫。因此守卫
/// 跟着代码一起迁到这里，基准值与 Lumi 仓保持一致。
@Suite("插件管理页布局")
struct PluginManagementLayoutTests {
    // MARK: - 基准值（与 Lumi 仓 SettingsLayoutConformanceTests 一致）

    /// 列表栏宽度。
    private static let listWidth = 300
    /// 主从容器不得写死的最小高度。
    private static let splitMinHeight = 520
    /// 详情栏内容内边距。
    private static let detailPadding = 22
    /// 曾经出现过的错误列表栏宽度。
    private static let staleListWidths = [280, 320, 340]
    /// 曾经出现过的错误主从容器最小高度。
    private static let staleMinHeights = [300, 460, 560]

    // MARK: - 源码定位

    /// 包根目录（`#filePath` 形如 `<pkg>/Tests/PluginPluginManagerTests/xxx.swift`）。
    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PluginPluginManagerTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // <pkg>
    }

    private static func source(_ relativePath: String) throws -> String {
        let url = Self.packageRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - 用例

    @Test("插件管理页遵循主从分栏基准间距")
    func conformsToMasterDetailBaselines() throws {
        let view = try Self.source("Sources/PluginPluginManager/Views/PluginManagementView.swift")
        let detail = try Self.source("Sources/PluginPluginManager/Views/PluginSettingsDetailView.swift")

        #expect(
            view.contains(".frame(width: \(Self.listWidth))"),
            Comment(rawValue: "列表栏宽度应为 \(Self.listWidth)")
        )
        #expect(
            view.contains(".frame(maxHeight: .infinity)"),
            Comment(rawValue: "主从容器必须用 .frame(maxHeight: .infinity) 占满剩余空间")
        )
        #expect(
            !view.contains(".frame(minHeight: \(Self.splitMinHeight)"),
            Comment(rawValue: "主从容器不得写死 minHeight: \(Self.splitMinHeight)"
                + "（会让整页超出窗口并被居中裁切，顶部与底部同时被切掉）")
        )
        #expect(
            detail.contains(".padding(\(Self.detailPadding))"),
            Comment(rawValue: "详情栏内容内边距应为 \(Self.detailPadding)")
        )

        for stale in Self.staleListWidths {
            #expect(
                !view.contains(".frame(width: \(stale))"),
                Comment(rawValue: "列表栏宽度仍是 \(stale)，应为 \(Self.listWidth)")
            )
        }
        for stale in Self.staleMinHeights {
            #expect(
                !view.contains("minHeight: \(stale)"),
                Comment(rawValue: "主从容器最小高度仍是 \(stale)")
            )
        }
    }

    @Test("贴边分栏页不得使用 PluginSettingsScaffold")
    func avoidsPluginSettingsScaffold() throws {
        // `PluginSettingsScaffold` 会在内容外多包一层 `VStack(spacing: 24)` + `Spacer`，
        // 那 24pt 会从内容区里被吃掉，主从容器比内容区矮一截，竖直分隔线到不了窗口底部。
        let view = try Self.source("Sources/PluginPluginManager/Views/PluginManagementView.swift")
        let code = String(Self.blankOutStringsAndComments(view))
        #expect(
            !code.contains("PluginSettingsScaffold"),
            Comment(rawValue: "贴边分栏页不得使用 PluginSettingsScaffold"
                + "（会吃掉 24pt 高度，竖直分隔线到不了窗口底部），"
                + "应改用 AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil)")
        )
    }

    /// 搜索框必须按插件数量阈值条件渲染：插件少的时候列表一眼可见，搜索是噪音。
    @Test("搜索框按插件数量阈值条件渲染")
    func searchBarIsGatedByPluginCount() throws {
        let view = try Self.source("Sources/PluginPluginManager/Views/PluginManagementView.swift")
        let code = String(Self.blankOutStringsAndComments(view))
        #expect(
            code.contains("if viewModel.showsSearchBar"),
            Comment(rawValue: "AppSearchBar 必须包在 `if viewModel.showsSearchBar` 里，"
                + "插件数量低于阈值时不显示搜索功能")
        )
        #expect(
            code.components(separatedBy: "AppSearchBar").count == 2,
            Comment(rawValue: "AppSearchBar 只应出现一次，且位于条件分支内")
        )
    }

    // MARK: - 源码扫描工具

    /// 把字符串字面量与注释替换成空格（保留换行，长度与行号不变）。
    ///
    /// 扫描组件名时必须先做这一步：注释里写「不能套 PluginSettingsScaffold」
    /// 这样的说明，被当成真实调用就会误报。
    private static func blankOutStringsAndComments(_ source: String) -> [Character] {
        var result = Array(source)
        var index = 0
        let count = result.count

        func blank(_ range: Range<Int>) {
            for position in range where position < count {
                if result[position] != "\n" {
                    result[position] = " "
                }
            }
        }

        func matches(_ needle: String, at position: Int) -> Bool {
            let characters = Array(needle)
            guard position + characters.count <= count else { return false }
            return Array(result[position..<(position + characters.count)]) == characters
        }

        while index < count {
            if result[index] == "\"" {
                if matches("\"\"\"", at: index) {
                    var cursor = index + 3
                    while cursor < count && !matches("\"\"\"", at: cursor) { cursor += 1 }
                    cursor = min(cursor + 3, count)
                    blank(index..<cursor)
                    index = cursor
                } else {
                    var cursor = index + 1
                    while cursor < count {
                        if result[cursor] == "\\" { cursor += 2; continue }
                        if result[cursor] == "\"" { cursor += 1; break }
                        if result[cursor] == "\n" { break }
                        cursor += 1
                    }
                    blank(index..<min(cursor, count))
                    index = min(cursor, count)
                }
            } else if matches("//", at: index) {
                var cursor = index
                while cursor < count && result[cursor] != "\n" { cursor += 1 }
                blank(index..<cursor)
                index = cursor
            } else if matches("/*", at: index) {
                var cursor = index + 2
                while cursor < count && !matches("*/", at: cursor) { cursor += 1 }
                cursor = min(cursor + 2, count)
                blank(index..<cursor)
                index = cursor
            } else {
                index += 1
            }
        }
        return result
    }
}
