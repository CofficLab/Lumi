import XCTest
@testable import EditorTextView

/// 大文件性能测试 - 模拟打开大型 log 文件的场景
/// 测量从文件内容加载到文本视图初始化的各个阶段耗时
///
/// 注：SPM 测试环境无窗口，TextView 初始化会为每个行片段创建真实 NSView，
/// 实测约 0.4s/千行。规模以"单测可在数十秒内完成"为准（1K 行 ≈ 0.4s，
/// 10K 行 ≈ 4.5s），并用 XCTMeasureOptions 限制迭代次数；
/// 真实大文件基准请用独立的 benchmark 工具，不要放进单测。
class LargeFilePerformanceTests: XCTestCase {

    // MARK: - Test Data Generation

    /// 生成模拟的 log 文件内容
    /// - Parameter lines: 行数
    /// - Returns: 模拟的 log 文本内容
    private func generateLogContent(lines: Int) -> String {
        var content = ""
        content.reserveCapacity(lines * 100) // 预估每行 100 字节

        for i in 0..<lines {
            content += "[2024-01-15 10:23:45.123] [INFO] [Thread-\(i % 8)] This is a log message line \(i) with some additional context and details that make it longer\n"
        }

        return content
    }

    private func measureOptions(iterations: Int = 3) -> XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = iterations
        return options
    }

    // MARK: - Phase 1: NSTextStorage 构建测试

    /// 测试 NSTextStorage 初始化性能
    /// 这是第一阶段：将字符串内容加载到 NSTextStorage
    func testNSTextStorageInitialization() throws {
        let content = generateLogContent(lines: 100_000)
        measure(metrics: [XCTClockMetric()], options: measureOptions()) {
            let _ = NSTextStorage(string: content)
        }
    }

    // MARK: - Phase 2: TextView 初始化测试

    /// 测试 TextView 完整初始化性能
    /// 这是第二阶段：TextView 初始化会触发 NSTextStorage 创建、TextLineStorage 构建、TextLayoutManager 布局
    func testTextViewCompleteInitialization() throws {
        let content = generateLogContent(lines: 5_000)
        measure(metrics: [XCTClockMetric()], options: measureOptions()) {
            let _ = TextView(
                string: content,
                wrapLines: false,
                isEditable: false,
                isSelectable: true
            )
        }
    }

    // MARK: - Phase 3: 大文件性能基准测试

    /// 测试较大文件（30K 行）的性能
    func testVeryLargeFilePerformance() throws {
        let lines = 30_000
        let content = generateLogContent(lines: lines)

        print("📊 Generating \(lines) lines of log content...")
        print("📊 Content size: \(content.utf8.count / 1024) KB")

        measure(metrics: [XCTClockMetric()], options: measureOptions(iterations: 2)) {
            let textView = TextView(
                string: content,
                wrapLines: false,
                isEditable: false,
                isSelectable: true
            )

            // 验证初始化成功
            XCTAssertGreaterThan(textView.string.count, 0)
        }
    }

    // MARK: - Phase 4: 不同规模文件对比测试

    /// 测试 1K 行文件
    func test1KLines() throws {
        let small = generateLogContent(lines: 1_000)
        measure(metrics: [XCTClockMetric()], options: measureOptions()) {
            let _ = TextView(string: small, wrapLines: false, isEditable: false, isSelectable: true)
        }
    }

    /// 测试 5K 行文件
    func test5KLines() throws {
        let medium = generateLogContent(lines: 5_000)
        measure(metrics: [XCTClockMetric()], options: measureOptions()) {
            let _ = TextView(string: medium, wrapLines: false, isEditable: false, isSelectable: true)
        }
    }

    /// 测试 10K 行文件
    func test10KLines() throws {
        let large = generateLogContent(lines: 10_000)
        measure(metrics: [XCTClockMetric()], options: measureOptions(iterations: 2)) {
            let _ = TextView(string: large, wrapLines: false, isEditable: false, isSelectable: true)
        }
    }
}
