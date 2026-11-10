import SwiftUI
import Testing
@testable import LumiUI

/// iOS 分组列表相关的组件行为约束。
///
/// 这些用例锁定的是「跨平台组件在 iOS 分支下的语义」，
/// 避免后续有人把 iOS 分支改回桌面观感而没有测试报警。
struct AppSettingsIOSComponentTests {

    @Test("iOS 语义色在两个平台都可解析")
    func semanticColorsResolveOnBothPlatforms() {
        // 构造即通过即可：语义色是平台相关的静态属性，任一平台缺失都会编译失败。
        _ = Color.lumiGroupedBackground
        _ = Color.lumiGroupedCardBackground
        _ = Color.lumiPrimaryLabel
        _ = Color.lumiSecondaryLabel
        _ = Color.lumiTertiaryLabel
        _ = Color.lumiSeparator
        _ = Color.lumiTertiaryFill
    }

    @Test("分组容器保留标题、页脚与内容")
    func groupKeepsTitleFooterAndContent() {
        let section = AppSettingSection(title: "Appearance", footer: "本地处理") {
            Text("row")
        }
        #expect(section.title == "Appearance")
        #expect(section.footer == "本地处理")
    }

    @Test("分组容器默认没有页脚")
    func groupFooterIsOptional() {
        let section = AppSettingSection(title: "Appearance") {
            Text("row")
        }
        #expect(section.footer == nil)
    }

    @Test("设置行支持行首色块与标题颜色覆盖")
    func rowSupportsLeadingColorAndTitleColor() {
        let row = AppSettingRow(
            title: "Theme",
            description: "晨曦",
            leadingColor: .orange,
            titleColor: .red
        ) {
            EmptyView()
        }
        #expect(row.leadingColor != nil)
        #expect(row.titleColor != nil)
        #expect(row.icon == nil)
    }

    @Test("值行把当前值放在尾部")
    func valueRowKeepsValueInTrailingSlot() {
        let row = AppSettingValueRow("Theme", value: "晨曦")
        #expect(row.value == "晨曦")
        #expect(row.title == "Theme")
    }

    @Test("对勾行记录选中态")
    func checkmarkRowTracksSelection() {
        let selected = AppSettingCheckmarkRow("晨曦", isSelected: true) {}
        let unselected = AppSettingCheckmarkRow("深海", isSelected: false) {}
        #expect(selected.isSelected)
        #expect(!unselected.isSelected)
    }

    @Test("披露行保留当前值")
    func disclosureRowKeepsValue() {
        let row = AppSettingDisclosureRow("外观模式", value: "跟随系统") {}
        #expect(row.value == "跟随系统")
    }

    @Test("动作行可标记为破坏性操作")
    func actionRowSupportsDestructiveFlag() {
        let row = AppSettingActionRow("Clear Cache", isDestructive: true) {}
        #expect(row.isDestructive)
        let normal = AppSettingActionRow("Replay Onboarding") {}
        #expect(!normal.isDestructive)
    }
}
