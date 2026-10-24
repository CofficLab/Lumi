import Foundation
import Testing

/// 设置窗口「间距一致性」守卫测试。
///
/// ## 为什么需要它
///
/// 设置窗口左侧是一串入口，用户会逐个点开。每一页的详情视图如果各写各的
/// padding / 圆角 / 栏宽，用户会看到页面宽度忽大忽小、列表忽宽忽窄、
/// 内容忽贴边忽留白——看起来像几个不同的 App 拼在一起。
///
/// ## 基准
///
/// 基准是「插件管理」页（`PluginManagementView`），它也是「外观」页
/// （上游 `LumiThemePack`）对齐时采用的同一套数值：
///
/// | 位置 | 数值 |
/// |------|------|
/// | 列表栏宽度 | 300 |
/// | 主从容器圆角 | 8 |
/// | 主从容器高度 | 占满剩余空间（不得写死下限） |
/// | 详情栏内容内边距 | 22 |
/// | 页面底部留白 | 16 |
///
/// 完整基准见 `.lumi/rules/settings-ui.md`。
///
/// ## 实现方式
///
/// 这些页面的布局参数是 SwiftUI 修饰符里的字面量（`300` / `8` / `520` …），
/// 它们不产出任何可断言的运行时对象，因此这里直接审计源码：
///
/// - **正向**：页面必须出现基准值——防止某个页面被悄悄改小/改大；
/// - **反向**：页面不得出现已登记的偏差值——防止"改回去了"；
/// - **完整性**：仓库里每个注册到设置窗口的入口都必须被本表覆盖，
///   新增设置页而不登记，会让本测试变红。
@Suite("Settings Layout Conformance")
struct SettingsLayoutConformanceTests {

    // MARK: - 基准常量

    /// 列表栏宽度（基准：插件管理页）。
    private static let listWidth = 300
    /// 主从容器圆角。
    private static let splitCornerRadius = 8
    /// 主从容器**不得**写死的下限。写死后整页会超出窗口、被窗口居中裁切，
    /// 顶部内容直接消失（详见 `.lumi/rules/settings-ui.md`）。
    private static let splitMinHeight = 520
    /// 页面底部留白。
    private static let bottomPadding = 16

    // MARK: - 受审页面

    /// 设置入口详情页的两种形态。
    private enum PageKind {
        /// 主从（列表 + 详情）布局。
        case masterDetail
        /// 单栏（分组卡片）布局。
        case singleColumn
    }

    private struct AuditedPage {
        /// 设置入口对应的详情视图类型名（用于完整性检查）。
        let viewTypeNames: [String]
        /// 相对仓库根的源码路径（页面主体）。
        let path: String
        /// 与该入口同属一个页面的其他文件（详情面板 / 外层容器），
        /// 断言会连同页面主体一起检查。
        let relatedPaths: [String]
        let kind: PageKind
        /// 详情栏内容内边距。`nil` 表示该页详情栏是「列表样式」（沿用列表的 8pt 留白）。
        let detailPadding: Int?
        /// 该页是否采用「贴边」形态：主从容器直接贴到窗口左右与底边，
        /// 不带外框描边，也没有页面底部留白。贴边页只校验列表栏宽度、
        /// 详情栏内边距与「不得写死 minHeight」三项。
        let isEdgeToEdge: Bool

        init(
            viewTypeNames: [String],
            path: String,
            relatedPaths: [String],
            kind: PageKind,
            detailPadding: Int?,
            isEdgeToEdge: Bool = false
        ) {
            self.viewTypeNames = viewTypeNames
            self.path = path
            self.relatedPaths = relatedPaths
            self.kind = kind
            self.detailPadding = detailPadding
            self.isEdgeToEdge = isEdgeToEdge
        }
    }

    private static let auditedPages: [AuditedPage] = [
        AuditedPage(
            viewTypeNames: ["PluginManagementView"],
            path: "Packages/PluginPluginManager/Sources/PluginPluginManager/Views/PluginManagementView.swift",
            relatedPaths: ["Packages/PluginPluginManager/Sources/PluginPluginManager/Views/PluginSettingsDetailView.swift"],
            kind: .masterDetail,
            detailPadding: 22,
            isEdgeToEdge: true
        ),
        AuditedPage(
            viewTypeNames: ["SettingsView"],
            path: "Packages/PluginProjects/Sources/PluginProjects/Views/SettingsView.swift",
            relatedPaths: [
                "Packages/PluginProjects/Sources/PluginProjects/Views/ProjectRAGStatusSection.swift",
            ],
            kind: .masterDetail,
            detailPadding: 22
        ),
        AuditedPage(
            viewTypeNames: ["MCPSettingsView"],
            path: "Packages/PluginMCP/Sources/PluginMCP/Views/MCPSettingsView.swift",
            relatedPaths: [],
            kind: .masterDetail,
            detailPadding: 22,
            isEdgeToEdge: true
        ),
        AuditedPage(
            viewTypeNames: ["ConversationStoreSettingsView"],
            path: "Packages/PluginConversationManager/Sources/PluginConversationManager/Views/ConversationStoreSettingsView.swift",
            relatedPaths: [],
            kind: .masterDetail,
            detailPadding: 22
        ),
        AuditedPage(
            viewTypeNames: ["HTTPExchangeSettingsView"],
            path: "Packages/PluginNetworkManager/Sources/PluginNetworkManager/Views/HTTPExchangeSettingsView.swift",
            relatedPaths: [],
            kind: .masterDetail,
            detailPadding: 22
        ),
        AuditedPage(
            viewTypeNames: ["SkillSettingsView"],
            path: "Packages/PluginSkill/Sources/PluginSkill/Views/SkillSettingsView.swift",
            relatedPaths: [],
            kind: .masterDetail,
            detailPadding: 22
        ),
        AuditedPage(
            viewTypeNames: ["AgentRulesSettingsView"],
            path: "Packages/PluginAgentRules/Sources/PluginAgentRules/Views/AgentRulesSettingsView.swift",
            relatedPaths: [],
            kind: .masterDetail,
            detailPadding: nil
        ),
        AuditedPage(
            viewTypeNames: ["MemorySettingsView"],
            path: "Packages/PluginMemory/Sources/PluginMemory/Views/MemorySettingsView.swift",
            relatedPaths: [],
            kind: .masterDetail,
            detailPadding: 22
        ),
        AuditedPage(
            viewTypeNames: ["ProviderSettingsPageContent", "CloudProviderSettingsPage", "LocalProviderSettingsPage"],
            path: "Packages/PluginLLMProviderSettings/Sources/PluginLLMProviderSettings/Views/ProviderSettingsPageContent.swift",
            relatedPaths: [
                "Packages/PluginLLMProviderSettings/Sources/PluginLLMProviderSettings/Views/ProviderDetailView.swift",
                "Packages/PluginLLMProviderSettings/Sources/PluginLLMProviderSettings/Views/ProviderModelDownloadView.swift",
                "Packages/PluginLLMProviderSettings/Sources/PluginLLMProviderSettings/Views/CustomCloudProviderEditor.swift",
            ],
            kind: .masterDetail,
            detailPadding: 22
        ),
        AuditedPage(
            viewTypeNames: ["GeneralSettingsDetailView"],
            path: "Packages/PluginSettingGeneral/Sources/PluginSettingGeneral/Views/GeneralSettingsDetailView.swift",
            relatedPaths: [],
            kind: .singleColumn,
            detailPadding: nil
        ),
        AuditedPage(
            viewTypeNames: ["ToolManagerSettingsView"],
            path: "Packages/PluginToolManager/Sources/PluginToolManager/Views/ToolManagerSettingsView.swift",
            relatedPaths: [
                "Packages/PluginToolManager/Sources/PluginToolManager/Views/ToolCallLogSettingsView.swift",
                "Packages/PluginToolManager/Sources/PluginToolManager/Views/ToolCallStatsSettingsView.swift",
            ],
            kind: .singleColumn,
            detailPadding: nil
        ),
        AuditedPage(
            viewTypeNames: ["ComputerUseSettingsView"],
            path: "Packages/PluginComputerUse/Sources/ComputerUsePlugin/Views/ComputerUseSettingsView.swift",
            relatedPaths: [],
            kind: .singleColumn,
            detailPadding: nil
        ),
        AuditedPage(
            viewTypeNames: ["QuickFileSearchSettingsView"],
            path: "Packages/PluginQuickFileSearch/Sources/PluginQuickFileSearch/Views/QuickFileSearchSettingsView.swift",
            relatedPaths: [],
            kind: .singleColumn,
            detailPadding: nil
        ),
        AuditedPage(
            viewTypeNames: ["LauncherSettingsView"],
            path: "Packages/PluginQuickLauncher/Sources/PluginQuickLauncher/Views/LauncherSettingsView.swift",
            relatedPaths: [],
            kind: .singleColumn,
            detailPadding: nil
        ),
        AuditedPage(
            viewTypeNames: ["WebServerSettingsView"],
            path: "Packages/PluginWebServer/Sources/PluginWebServer/WebServerSettingsView.swift",
            relatedPaths: [],
            kind: .singleColumn,
            detailPadding: nil
        ),
        AuditedPage(
            viewTypeNames: ["ACPSettingsView"],
            path: "Packages/PluginACP/Sources/PluginACP/Views/ACPSettingsView.swift",
            relatedPaths: [],
            kind: .singleColumn,
            detailPadding: nil
        ),
        AuditedPage(
            viewTypeNames: ["MailSettingsView"],
            path: "Packages/PluginMail/Sources/PluginMail/Views/MailSettingsView.swift",
            relatedPaths: [],
            kind: .singleColumn,
            detailPadding: nil
        ),
        AuditedPage(
            viewTypeNames: ["AppStoreConnectSettingsView", "AccountPage"],
            path: "Packages/PluginAppStoreConnect/Sources/PluginAppStoreConnect/Sources/Views/Pages/AccountPage.swift",
            relatedPaths: ["Packages/PluginAppStoreConnect/Sources/PluginAppStoreConnect/Sources/Views/AppStoreConnectSettingsView.swift"],
            kind: .singleColumn,
            detailPadding: nil
        ),
        AuditedPage(
            viewTypeNames: ["ActivityHeatmapSettingsView"],
            path: "Packages/PluginActivityHeatmap/Sources/PluginActivityHeatmap/ActivityHeatmapPlugin.swift",
            relatedPaths: [
                "Packages/PluginActivityHeatmap/Sources/PluginActivityHeatmap/Views/GitActivityHeatmapProjectSection.swift",
            ],
            kind: .singleColumn,
            detailPadding: nil
        ),
        AuditedPage(
            viewTypeNames: ["ScreenRecorderSettingsView"],
            path: "Packages/PluginScreenRecorder/Sources/ScreenRecorderPlugin/Views/ScreenRecorderSettingsView.swift",
            relatedPaths: [],
            kind: .singleColumn,
            detailPadding: nil
        ),
        AuditedPage(
            viewTypeNames: ["TextActionsSettingsView"],
            path: "Packages/PluginTextActions/Sources/PluginTextActions/TextActionsV2Support.swift",
            relatedPaths: [],
            kind: .singleColumn,
            detailPadding: nil
        ),
    ]

    /// 详情视图由外部包（`LumiThemePack`）提供，不在本仓库内审计。
    private static let externallyOwnedViewTypes: Set<String> = [
        "ThemeSettingsDetailView",
    ]

    /// 框架/容器类型，不是设置入口详情视图。
    private static let frameworkViewTypes: Set<String> = [
        "AnyView",
        "EmptyView",
    ]

    // MARK: - 用例

    @Test("每个设置入口的详情页都使用基准间距")
    func auditedPagesMatchBaseline() throws {
        let root = try Self.repositoryRoot()
        var failures: [String] = []

        for page in Self.auditedPages {
            let url = root.appendingPathComponent(page.path)
            // 插件可能被整体移除（例如性能跑分插件被下线），此时源码文件不复存在。
            // 没有源码就没有可审计的布局，跳过即可——「注册到设置窗口的入口是否
            // 都被审计表覆盖」由 `everyRegisteredEntryIsAudited` 单独把关。
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let source = try String(contentsOf: url, encoding: .utf8)
            var combinedSource = source
            for relatedPath in page.relatedPaths {
                let relatedURL = root.appendingPathComponent(relatedPath)
                guard FileManager.default.fileExists(atPath: relatedURL.path) else { continue }
                combinedSource += try String(contentsOf: relatedURL, encoding: .utf8)
            }

            switch page.kind {
            case .masterDetail:
                failures.append(contentsOf: Self.masterDetailFailures(
                    page: page,
                    source: combinedSource
                ))
            case .singleColumn:
                failures.append(contentsOf: Self.singleColumnFailures(
                    page: page,
                    source: combinedSource
                ))
            }
        }

        if !failures.isEmpty {
            Issue.record(
                Comment(rawValue: """
                设置入口详情页与「插件管理」基准不一致：

                \(failures.joined(separator: "\n"))
                """)
            )
        }
    }

    @Test("设置入口详情页统一使用原生 GroupBox 卡片体系")
    func settingsPagesUseNativeGroupBoxCards() throws {
        let root = try Self.repositoryRoot()
        var failures: [String] = []

        for (path, source) in try Self.cardFamilySources(root: root) {
            // 先把注释与字符串字面量涂成空格，避免「注释里提到组件名」被误判。
            let code = String(Self.blankOutStringsAndComments(source))

            // 1) 不得再出现自绘新卡片家族（玻璃拟态卡片）。
            for custom in Self.customCardComponents {
                if code.contains(custom) {
                    failures.append(
                        "- \(path)：仍在使用自绘卡片组件 \(custom)，"
                        + "设置页应改用原生 AppSettingSection + AppSettingRow + 行间 Divider()"
                    )
                }
            }

            // 2) 不得手写 GroupBox（分组一律走 `AppSettingSection`）。
            if code.contains("GroupBox {") {
                failures.append("- \(path)：仍在手写 GroupBox，应改用 AppSettingSection")
            }
        }

        if !failures.isEmpty {
            Issue.record(
                Comment(rawValue: """
                设置入口详情页仍在使用自绘新卡片体系：

                \(failures.joined(separator: "\n"))
                """)
            )
        }
    }

    /// 自绘新卡片家族（玻璃拟态、标题在卡外、每行一个独立圆角块）。
    ///
    /// 2026-10-25 起设置窗口不再使用这套组件——用户明确认为它的观感不如
    /// 原生 GroupBox（标题在卡内、行间一条 `Divider()`）。
    ///
    /// 注意：这些名字与原生家族只差一个字母（`AppSettings…` vs `AppSetting…`），
    /// 匹配时必须带右括号，否则两者会互相命中。
    private static let customCardComponents = [
        "AppCard",
        "AppSettingsSection(",
        "AppSettingsRow(",
        "AppSettingsToggleRow(",
        "AppSettingsStepperRow(",
        "AppSettingsPickerRow(",
        "AppSettingsSegmentedPickerRow(",
        "AppSettingsReadOnlyRow(",
        "AppSettingsSecureFieldRow(",
    ]

    // MARK: - 卡片体系源码扫描

    /// 不在设置窗口侧边栏、但同样属于「设置类界面」的插件面板文件。
    ///
    /// 它们与设置入口详情页共用同一套卡片组件，必须一起纳入检查，否则
    /// 「统一成旧版 GroupBox 观感」会被这些页面破功。
    private static let extraCardFamilyPaths = [
        "Packages/PluginMail/Sources/PluginMail/Views/MailAccountFormView.swift",
        "Packages/PluginClipboardManager/Sources/PluginClipboardManager/Views/ClipboardSettingsView.swift",
        "Packages/PluginInput/Sources/PluginInput/Views/InputSettingsView.swift",
        "Packages/PluginRClick/Sources/PluginRClick/Views/RClickSettingsView.swift",
        "Packages/PluginSystemBenchmark/Sources/PluginSystemBenchmark/Views/SystemBenchmarkView.swift",
        "Packages/PluginDevice/Sources/PluginDevice/Views/DeviceInfoView.swift",
    ]

    /// 需要检查卡片体系的源码：受审设置入口页面（主体 + 相关文件）+ 插件面板设置页。
    private static func cardFamilySources(root: URL) throws -> [(path: String, source: String)] {
        var paths: [String] = []
        for page in auditedPages {
            paths.append(page.path)
            paths.append(contentsOf: page.relatedPaths)
        }
        paths.append(contentsOf: extraCardFamilyPaths)

        var seen = Set<String>()
        var result: [(path: String, source: String)] = []
        for path in paths where seen.insert(path).inserted {
            let url = root.appendingPathComponent(path)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let source = try String(contentsOf: url, encoding: .utf8)
            result.append((path, source))
        }
        return result
    }

    /// 把字符串字面量与注释替换成空格（保留换行，长度与行号不变）。
    ///
    /// 扫描卡片组件时必须先做这一步：注释里写「已改用 AppSettingsSection」这类
    /// 说明文字不应该被判成违规。
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

    @Test("仓库里每个注册到设置窗口的入口都被审计表覆盖")
    func everyRegisteredEntryIsAudited() throws {
        let root = try Self.repositoryRoot()
        let packagesRoot = root.appendingPathComponent("Packages")
        let fileManager = FileManager.default
        let packageDirectories = try fileManager.contentsOfDirectory(
            at: packagesRoot,
            includingPropertiesForKeys: [.isDirectoryKey]
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }

        var registeredViewTypes: Set<String> = []
        for package in packageDirectories {
            let sources = package.appendingPathComponent("Sources")
            guard fileManager.fileExists(atPath: sources.path) else { continue }
            for file in try Self.swiftFiles(under: sources) {
                let source = try String(contentsOf: file, encoding: .utf8)
                registeredViewTypes.formUnion(Self.registeredViewTypes(in: source))
            }
        }

        let auditedViewTypes = Set(Self.auditedPages.flatMap(\.viewTypeNames))
        let uncovered = registeredViewTypes
            .subtracting(auditedViewTypes)
            .subtracting(Self.externallyOwnedViewTypes)
            .subtracting(Self.frameworkViewTypes)
            .sorted()

        if !uncovered.isEmpty {
            Issue.record(
                Comment(rawValue: """
                以下设置入口详情视图未被审计表覆盖，请补充到 \
                SettingsLayoutConformanceTests.auditedPages：
                \(uncovered.joined(separator: ", "))
                """)
            )
        }
    }

    // MARK: - 校验实现

    private static func masterDetailFailures(
        page: AuditedPage,
        source: String
    ) -> [String] {
        var failures: [String] = []

        // 列表栏宽度。
        if !source.contains(".frame(width: \(listWidth))") {
            failures.append("- \(page.path)：列表栏宽度应为 \(listWidth)")
        }
        // 贴边页：主从容器直接贴到窗口边缘，没有外框圆角 / 描边，也没有底部留白。
        if !page.isEdgeToEdge {
            // 主从容器圆角。
            if !source.contains("cornerRadius: \(splitCornerRadius)") {
                failures.append("- \(page.path)：主从容器圆角应为 \(splitCornerRadius)")
            }
        }
        // 主从容器必须吃满剩余空间。
        if !source.contains(".frame(maxHeight: .infinity)") {
            failures.append("- \(page.path)：主从容器必须用 .frame(maxHeight: .infinity) 占满剩余空间")
        }
        // 主从容器不得写死下限：页面比窗口高时，外层容器被撑大，窗口按居中裁切，
        // 顶部与底部同时被切掉（顶部卡片标题会整块消失）。
        if source.contains(".frame(minHeight: \(splitMinHeight)") {
            failures.append(
                "- \(page.path)：主从容器不得写死 minHeight: \(splitMinHeight)"
                + "（会让整页超出窗口并被居中裁切，只保留 maxHeight: .infinity 即可）"
            )
        }
        // 页面底部留白。贴边页底部直接贴到窗口边缘，不需要留白。
        if !page.isEdgeToEdge,
           !source.contains(".padding(.bottom, \(bottomPadding))") {
            failures.append("- \(page.path)：缺少 .padding(.bottom, \(bottomPadding)) 底部留白")
        }
        // 详情栏内容内边距。
        if let detailPadding = page.detailPadding,
           !source.contains(".padding(\(detailPadding))") {
            failures.append("- \(page.path)：详情栏内容内边距应为 \(detailPadding)")
        }
        // 已登记的偏差值不得复活。
        for stale in staleListWidths {
            if source.contains(".frame(width: \(stale))") {
                failures.append("- \(page.path)：列表栏宽度仍是 \(stale)，应为 \(listWidth)")
            }
        }
        for stale in staleMinHeights {
            if source.contains("minHeight: \(stale)") {
                failures.append("- \(page.path)：主从容器最小高度仍是 \(stale)")
            }
        }
        // 主从容器必须保留描边（不能只 clip 不描边）。贴边页没有外框，不需要描边。
        if !page.isEdgeToEdge,
           !source.contains("strokeBorder") {
            failures.append("- \(page.path)：主从容器缺少 1px 描边")
        }
        return failures
    }

    private static func singleColumnFailures(
        page: AuditedPage,
        source: String
    ) -> [String] {
        var failures: [String] = []

        // 必须走共享 scaffold，不允许自建外框。
        if !source.contains("AppSettingsContentScaffold")
            && !source.contains("PluginSettingsScaffold") {
            failures.append("- \(page.path)：未使用 AppSettingsContentScaffold / PluginSettingsScaffold")
        }
        // 禁止原生 Form（与 .lumi/rules/settings-ui.md 冲突）。
        if source.contains("Form {") || source.contains("Form(") {
            failures.append("- \(page.path)：使用了原生 Form，设置页应改用共享卡片组件")
        }
        // 禁止自建外框内边距。
        if source.contains(".padding(18)") {
            failures.append("- \(page.path)：使用了自建外框 .padding(18)，应由共享 scaffold 统一留白")
        }
        return failures
    }

    /// 曾经出现过的错误列表栏宽度。
    private static let staleListWidths = [280, 320, 340]
    /// 曾经出现过的错误主从容器最小高度。
    private static let staleMinHeights = [300, 460, 560]

    // MARK: - 源码扫描

    /// 从设置入口注册代码里提取详情视图类型名。
    ///
    /// 注册形如 `SettingEntryItem(id: …) { SomeSettingsView() }`，因此在每个
    /// `SettingEntryItem` 之后的一小段代码里找 `XxxView(` / `XxxPage(` 即可。
    private static func registeredViewTypes(in source: String) -> Set<String> {
        var result: Set<String> = []
        var searchStart = source.startIndex
        while let range = source.range(of: "SettingEntryItem(", range: searchStart..<source.endIndex) {
            let tail = String(source[range.upperBound...].prefix(600))
            let pattern = #"([A-Z][A-Za-z0-9]*(?:View|Page))\("#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsRange = NSRange(tail.startIndex..<tail.endIndex, in: tail)
                for match in regex.matches(in: tail, range: nsRange) {
                    guard let matchRange = Range(match.range(at: 1), in: tail) else { continue }
                    result.insert(String(tail[matchRange]))
                }
            }
            searchStart = range.upperBound
        }
        return result
    }

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

    private struct RepositoryRootNotFoundError: Error {}
}
