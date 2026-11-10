import CoreGraphics
import Foundation
import Testing
@testable import KitMarkdown

/// V4（ZCode）表格与图片几何契约测试。
///
/// 基准是 ZCode 3.15.1 计划第 2.5 节：
/// - 表格：frame 圆角 12、1px border；内部横向滚动，不能撑宽 timeline；
///   th/td 水平 12、垂直 8；th 左对齐、字重 400；
///   单元格最小 64、最大 448；
/// - 图片：单图最大为容器 50% 宽，最大高 360，圆角 12；
///   连续图片组成 gallery；失败显示错误占位。
///
/// - Important: 这些差异必须**纳入 theme**，不得全局替换旧值。
@Suite("ZCode 表格与媒体几何")
struct ZCodeTableMediaLayoutTests {

    // MARK: - 表格

    @Test("表格圆角是 12、边框 1px")
    func tableFrameGeometry() {
        let theme = MarkdownTheme.zcode

        #expect(theme.tableCornerRadius == 12)
        #expect(theme.tableBorderWidth == 1)
    }

    @Test("单元格内边距是水平 12、垂直 8")
    func tableCellPadding() {
        let theme = MarkdownTheme.zcode

        #expect(theme.tableCellHorizontalPadding == 12)
        #expect(theme.tableCellVerticalPadding == 8)
    }

    @Test("表头左对齐、字重 400")
    func tableHeaderStyle() {
        let theme = MarkdownTheme.zcode

        #expect(theme.tableHeaderFontSize == 14)
        #expect(theme.tableHeaderWeight == .regular)
        #expect(theme.tableHeaderAlignment == .leading)
    }

    @Test("单元格最小宽 64、最大宽 448")
    func tableCellWidthRange() {
        let theme = MarkdownTheme.zcode

        #expect(theme.tableCellMinWidth == 64)
        #expect(theme.tableCellMaxWidth == 448)
    }

    @Test("表格内部横向滚动，不撑宽 timeline")
    func tableScrollsHorizontally() {
        #expect(MarkdownTheme.zcode.tableScrollsHorizontally == true)
    }

    // MARK: - 图片

    @Test("图片最大宽度是容器的 50%")
    func imageMaxWidthIsHalfContainer() {
        #expect(MarkdownTheme.zcode.imageMaxWidthFraction == 0.5)
    }

    @Test("图片最大高是 360")
    func imageMaxHeightIs360() {
        #expect(MarkdownTheme.zcode.imageMaxHeight == 360)
    }

    @Test("图片圆角是 12")
    func imageCornerRadiusIs12() {
        #expect(MarkdownTheme.zcode.imageCornerRadius == 12)
    }

    @Test("连续图片组成 gallery")
    func imagesFormGallery() {
        #expect(MarkdownTheme.zcode.imagesFormGallery == true)
    }

    @Test("图片失败显示错误占位")
    func imageFailureShowsPlaceholder() {
        #expect(MarkdownTheme.zcode.imageShowsErrorPlaceholder == true)
    }

    // MARK: - 旧主题不变

    @Test("旧主题没有 V4 的表格与图片覆盖")
    func legacyThemeHasNoZCodeTableMediaOverrides() {
        let standard = MarkdownTheme.standard

        // V1–V3 的表格圆角仍是 6，表头仍是 12/semibold。
        #expect(standard.tableCornerRadius == 6)
        #expect(standard.tableHeaderFontSize == 12)
        #expect(standard.tableHeaderWeight == .semibold)
        #expect(standard.tableCellHorizontalPadding == 10)
        #expect(standard.tableCellMinWidth == 0)
        #expect(standard.tableCellMaxWidth == 0)
    }
}
