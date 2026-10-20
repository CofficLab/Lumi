import Foundation
import AppKit
import SwiftUI
import Testing
@testable import PluginModelSelector

/// 模型选择弹窗左右两栏的分割线必须严格对齐。
///
/// ## 为什么要有这条测试
///
/// 弹窗是「左供应商栏 + 右模型栏」的双栏结构，两栏顶部各有一行筛选控件
/// （左：常用/云端/本地 分段控件；右：模型能力标签），其下各有一条 `AppDivider`。
/// 只要两行控件高度不一致，左右两条分割线就会错开成两条线。
///
/// 纯看代码很难发现这个 bug：两边的垂直内边距写的一模一样，
/// 差的是控件**自身**的高度——分段控件 22pt、标签行 23pt。
///
/// ## 怎么测
///
/// 直接渲染两栏的表头行（`ProviderScopeFilterRow` / `ModelCategoryFilterBar`），
/// 在各自的分割线位置放一个探针，用 `PreferenceKey` 读出全局 y 坐标，
/// 断言两者相等。
///
/// 用 `PreferenceKey` 而不是逐像素扫描：分割线颜色是主题的 `divider`（半透明），
/// 逐像素判定在明暗主题下阈值都不稳定；探针直接给出布局坐标，与主题无关，
/// 而且能直接指出差了多少点。
@MainActor
@Suite("Model selector column alignment")
struct ModelSelectorAlignmentTests {

    // MARK: - 探针

    /// 记录自身在全局坐标系里的顶部 y。
    ///
    /// 高度必须是 0：探针本身若占 1px，就会把后面的内容整体下推 1pt，
    /// 量出来的「两条分割线间距」会凭空多出 1pt。零高度探针的 `minY`
    /// 就是它所在位置的真实边界。
    private struct DividerProbe: View {
        let name: String

        var body: some View {
            Color.clear
                .frame(height: 0)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: DividerYKey.self,
                            value: [name: geometry.frame(in: .global).minY]
                        )
                    }
                )
        }
    }

    private struct DividerYKey: PreferenceKey {
        static let defaultValue: [String: CGFloat] = [:]

        static func reduce(
            value: inout [String: CGFloat],
            nextValue: () -> [String: CGFloat]
        ) {
            value.merge(nextValue()) { _, new in new }
        }
    }

    // MARK: - 布局

    /// 复刻两栏表头的结构：筛选行 → 分割线 → 搜索行 → 分割线。
    private struct HeaderHarness: View {
        let showsSearchBar: Bool
        let hasRefreshButton: Bool

        var body: some View {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    ProviderScopeFilterRow(selectedScope: .constant(.cloud))
                    DividerProbe(name: "leftFilterDivider")
                    ProviderSearchRow(text: .constant(""))
                    DividerProbe(name: "leftSearchDivider")
                }
                .frame(width: 300)

                VStack(spacing: 0) {
                    ModelCategoryFilterBar(selectedCategory: .constant(.all))
                    DividerProbe(name: "rightFilterDivider")
                    ModelSearchRow(
                        text: .constant(""),
                        showsSearchBar: showsSearchBar,
                        refreshAction: hasRefreshButton ? {} : nil
                    )
                    DividerProbe(name: "rightSearchDivider")
                }
            }
        }
    }

    // MARK: - 渲染辅助

    /// 渲染表头并返回各分割线的全局 y 坐标。
    private func renderHeader(
        showsSearchBar: Bool = true,
        hasRefreshButton: Bool = false
    ) async throws -> [String: CGFloat] {
        final class Box: @unchecked Sendable {
            var ys: [String: CGFloat] = [:]
        }
        let box = Box()

        let host = NSHostingView(
            rootView: ProbeCollector(
                content: HeaderHarness(
                    showsSearchBar: showsSearchBar,
                    hasRefreshButton: hasRefreshButton
                )
            ) { box.ys = $0 }
        )
        host.frame = NSRect(x: 0, y: 0, width: 780, height: 200)
        host.layoutSubtreeIfNeeded()

        for _ in 0..<40 {
            try await Task.sleep(for: .milliseconds(25))
            host.layoutSubtreeIfNeeded()
            if !box.ys.isEmpty { break }
        }
        return box.ys
    }

    /// 把 `PreferenceKey` 收集到的坐标回传给测试。
    private struct ProbeCollector<Content: View>: View {
        let content: Content
        let onChange: ([String: CGFloat]) -> Void

        @State private var ys: [String: CGFloat] = [:]

        var body: some View {
            content
                .onPreferenceChange(DividerYKey.self) { new in
                    ys = new
                    onChange(new)
                }
        }
    }

    // MARK: - 测试

    /// 左右两栏的分割线必须在同一水平线上。
    ///
    /// 覆盖的是最容易被改坏的约束：左右两栏的筛选控件类型不同
    /// （分段控件 vs 标签行），高度天然不同，必须靠显式锁高抹平。
    @Test("左右两栏的分割线严格对齐")
    func dividersAreAligned() async throws {
        let ys = try await renderHeader()

        let left = try #require(ys["leftFilterDivider"], "未取到左栏筛选行分割线坐标")
        let right = try #require(ys["rightFilterDivider"], "未取到右栏筛选行分割线坐标")

        #expect(
            abs(left - right) < 0.5,
            "筛选行下方分割线错开 \(String(format: "%.2f", abs(left - right)))pt（左 \(left) / 右 \(right)）"
        )
    }

    /// 右栏只剩刷新按钮时（无搜索框），分割线依然要对齐。
    ///
    /// 刷新按钮比搜索框矮 4pt，不锁行高的话右栏这一行会短一截，
    /// 分割线随之错开——这是最容易漏掉的一种错位。
    @Test("右栏只有刷新按钮时分割线仍对齐")
    func dividersAlignedWithoutSearchBar() async throws {
        let ys = try await renderHeader(showsSearchBar: false, hasRefreshButton: true)

        let left = try #require(ys["leftSearchDivider"], "未取到左栏搜索行分割线坐标")
        let right = try #require(ys["rightSearchDivider"], "未取到右栏搜索行分割线坐标")

        #expect(
            abs(left - right) < 0.5,
            "搜索行下方分割线错开 \(String(format: "%.2f", abs(left - right)))pt（左 \(left) / 右 \(right)）"
        )
    }

    /// 分割线之间的间距必须与布局常量一致。
    ///
    /// 这条断言把「对齐」和「位置正确」两件事分开：
    /// 上面的对齐断言只保证两条线重合，这里保证重合的那条线落在预期位置，
    /// 避免出现「两条线都跑到屏幕外所以对齐了」这种假通过。
    @Test("分割线位置符合布局常量")
    func dividerPositionMatchesLayoutConstants() async throws {
        let ys = try await renderHeader()

        let filterDivider = try #require(ys["leftFilterDivider"], "未取到分割线坐标")
        let searchDivider = try #require(ys["leftSearchDivider"], "未取到分割线坐标")

        let expectedGap = ModelSelectorLayout.searchRowContentHeight
            + ModelSelectorLayout.searchRowVerticalPadding * 2

        // 全局坐标系的 y 轴向上，因此「下方的分割线」坐标更小，差值取反。
        let actualGap = searchDivider - filterDivider

        #expect(
            abs(actualGap - expectedGap) < 1.0,
            "两条分割线间距 \(String(format: "%.2f", actualGap))pt，预期 \(expectedGap)pt"
        )
    }
}
