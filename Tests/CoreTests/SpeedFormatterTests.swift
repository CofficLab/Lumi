#if canImport(XCTest)
import XCTest
@testable import Lumi

/// 网速格式化工具（SpeedFormatter）单元测试
///
/// 验证 `SpeedFormatter` 的静态方法，该工具用于将字节数/秒转换为人类可读的速度字符串，
/// 主要用在状态栏等空间受限的 UI 区域。
///
/// 测试覆盖：
/// - `formatForStatusBar`：不同数量级的速度格式化（B/KB/MB/GB）
/// - `estimatedWidth`：格式化文本的预估渲染宽度
/// - `estimatedTotalWidth`：上传+下载双行速度的预估总宽度
final class SpeedFormatterTests: XCTestCase {

    // MARK: - formatForStatusBar

    /// 验证小于 1KB 的速度以字节为单位格式化，不带小数。
    func testFormatBytesPerSecond() {
        XCTAssertEqual(SpeedFormatter.formatForStatusBar(500), "500B/s")
    }

    /// 验证 1KB ~ 1MB 范围内的速度以 KB 为单位格式化，不带小数。
    ///
    /// - 1024 B/s → "1KB/s"（精确 1KB）
    /// - 512KB/s → "512KB/s"（中间值）
    func testFormatKilobytesPerSecond() {
        XCTAssertEqual(SpeedFormatter.formatForStatusBar(1024), "1KB/s")
        XCTAssertEqual(SpeedFormatter.formatForStatusBar(512 * 1024), "512KB/s")
    }

    /// 验证 1MB ~ 1GB 范围内的速度以 MB 为单位格式化，保留一位小数。
    ///
    /// - 1MB/s → "1.0MB/s"（精确 1MB，仍显示小数位）
    /// - 1.5MB/s → "1.5MB/s"（带小数的中间值）
    func testFormatMegabytesPerSecond() {
        XCTAssertEqual(SpeedFormatter.formatForStatusBar(1024 * 1024), "1.0MB/s")
        XCTAssertEqual(SpeedFormatter.formatForStatusBar(1.5 * 1024 * 1024), "1.5MB/s")
    }

    /// 验证 ≥1GB 的速度以 GB 为单位格式化，保留一位小数。
    func testFormatGigabytesPerSecond() {
        XCTAssertEqual(SpeedFormatter.formatForStatusBar(1024 * 1024 * 1024), "1.0GB/s")
    }

    /// 验证零速度的格式化结果为 "0B/s"。
    ///
    /// 零速度可能出现在网络未连接或传输尚未开始的场景。
    func testFormatZero() {
        XCTAssertEqual(SpeedFormatter.formatForStatusBar(0), "0B/s")
    }

    // MARK: - estimatedWidth

    /// 验证预估宽度为正值。
    ///
    /// `estimatedWidth` 用于状态栏动态宽度计算，返回值必须大于 0。
    func testEstimatedWidth_isPositive() {
        let width = SpeedFormatter.estimatedWidth(for: "1.0MB/s")
        XCTAssertTrue(width > 0)
    }

    // MARK: - estimatedTotalWidth

    /// 验证上传+下载双行速度的预估总宽度为正值。
    ///
    /// `estimatedTotalWidth` 综合了 Logo、上传文本、下载文本、间距和边距，
    /// 用于状态栏整体宽度布局，返回值必须大于 0。
    func testEstimatedTotalWidth_isPositive() {
        let width = SpeedFormatter.estimatedTotalWidth(uploadSpeed: 1024, downloadSpeed: 1024 * 1024)
        XCTAssertTrue(width > 0)
    }
}
#endif
