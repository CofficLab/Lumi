import AppKit
import Foundation
import LumiUI
import SwiftUI
import Testing
@testable import PluginSkill

/// 技能设置页的「贴边分栏」布局守卫。
///
/// ## 为什么需要它
///
/// 2026-10-25 用户反馈：「技能」页中间那根竖直分隔线没有延伸到窗口底部，
/// 而「插件管理」页是到底的。
///
/// 根因不在技能页自己写的 padding，而在它把页面套进了 `PluginSettingsScaffold`：
/// 这个脚手架在内容外又多包了一层 `VStack(alignment: .leading, spacing: 24)` +
/// `Spacer`，那 24 的间距会从内容区里「吃掉」高度，于是主从容器比内容区矮 24pt，
/// 竖线在离窗口底边 24pt 的地方就断了。
///
/// 基准写法见 `.lumi/rules/settings-ui.md`「分栏页：贴边（edge-to-edge）」：
/// 贴边页必须**直接**用 `AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil)`。
@Suite("Skill Settings Layout")
@MainActor
struct SkillSettingsLayoutTests {

    // MARK: - 基准常量

    /// `AppSettingsContentScaffold` 给内容区的顶部留白。
    private static let scaffoldTopPadding: CGFloat = 24
    /// SwiftUI 给 `GeometryReader` 的固定理想高度（与内容无关）。
    private static let geometryBaseline: CGFloat = 10
    /// `PluginSettingsScaffold` 在内容外多包的那层 VStack 间距。
    private static let pluginScaffoldSpacing: CGFloat = 24

    /// 贴边页应有的理想高度：顶部留白 + GeometryReader 基准。
    private static var expectedIdealHeight: CGFloat {
        scaffoldTopPadding + geometryBaseline
    }

    // MARK: - 用例

    @Test("技能页不引入额外垂直间隙：主从容器要贴到窗口底边")
    func skillPageAddsNoVerticalSlack() {
        let ideal = Self.idealHeight {
            SkillSettingsView(viewModel: SkillSettingsViewModel())
        }

        #expect(
            abs(ideal - Self.expectedIdealHeight) < 0.5,
            """
            技能页的理想高度应为 \(Self.expectedIdealHeight)\
            （内容区顶部留白 \(Self.scaffoldTopPadding) + GeometryReader 基准 \(Self.geometryBaseline)），\
            实际为 \(ideal)。
            多出来的高度来自外层脚手架的 VStack 间距——主从容器会比内容区矮一截，\
            竖直分隔线到不了窗口底部。贴边页请直接用 \
            AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil)。
            """
        )
    }

    @Test("PluginSettingsScaffold 会从内容区里吃掉 24pt 高度")
    func pluginSettingsScaffoldEatsVerticalSpace() {
        let direct = Self.idealHeight {
            AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
                MasterDetailProbe()
            }
        }
        let nested = Self.idealHeight {
            PluginSettingsScaffold("probe", showHeader: false, scrollsContent: false) {
                MasterDetailProbe()
            }
        }

        #expect(
            abs((nested - direct) - Self.pluginScaffoldSpacing) < 0.5,
            """
            PluginSettingsScaffold 比 AppSettingsContentScaffold 多占 \
            \(Self.pluginScaffoldSpacing)pt 高度（实测 \(nested) vs \(direct)）。
            这 24pt 会从内容区里被吃掉，主从容器到不了窗口底部——贴边页不要套它。
            若 LumiUI 已修复该脚手架，请同步更新本用例与登记的偏差清单。
            """
        )
    }

    // MARK: - Helpers

    /// 测量视图的理想高度（`NSHostingView.fittingSize` 会触发一次 SwiftUI 布局）。
    private static func idealHeight<V: View>(@ViewBuilder _ view: () -> V) -> CGFloat {
        NSHostingView(rootView: view()).fittingSize.height
    }

    /// 与技能页同构的主从容器：列表 300 + 竖直分隔线 + 详情栏。
    private struct MasterDetailProbe: View {
        var body: some View {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    Color.clear.frame(height: 30)
                    AppDivider()

                    HStack(spacing: 0) {
                        Color.clear
                            .frame(width: 300)
                            .frame(maxHeight: .infinity)

                        AppDivider(.vertical)

                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(width: proxy.size.width + 48, alignment: .topLeading)
                .offset(x: -24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}
