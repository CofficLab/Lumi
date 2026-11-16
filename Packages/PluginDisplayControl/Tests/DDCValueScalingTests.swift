import Testing
@testable import DisplayControlPlugin

/// 回归 #837：DDC 读数/写回必须以显示器报告的原始 VCP 满量程为准。
///
/// 原实现把 max 截断到 100（`min(values.max, 100)`），max>100 的显示器
/// 读数被压成 100%、写回硬件值按比例偏小。修复后百分比 = current/max*100，
/// 写回 = percentage/100*max，均用原始 max。
@Suite("DDC 值换算（回归 #837）")
struct DDCValueScalingTests {

    @Test("读取百分比必须用显示器报告的完整满量程（max>100）")
    func readUsesFullReportedMax() {
        // 显示器报告 current=128, max=255：真实亮度约 50.2%，而非 100%。
        let result = DDCValueScaling.read(current: 128, reportedMax: 255)
        #expect(abs(result.percentage - 128.0 / 255.0 * 100) < 0.0001)
        #expect(result.percentage < 100)
        // 缓存的满量程必须是原始 255，写回才能正确缩放。
        #expect(result.maxToCache == 255)
    }

    @Test("写回硬件值必须按完整满量程缩放（max>100）")
    func writeScalesByFullReportedMax() {
        // 50% × max=255 → 127.5 → 四舍五入 128，而非截断后的 50。
        #expect(DDCValueScaling.write(percentage: 50, maxValue: 255) == 128)
    }

    @Test("current 等于 max 时读数为 100%")
    func readAtMaxIs100Percent() {
        let result = DDCValueScaling.read(current: 255, reportedMax: 255)
        #expect(result.percentage == 100)
        #expect(result.maxToCache == 255)
    }

    @Test("current 超过 max 时读数夹到 100%")
    func readClampsCurrentAboveMax() {
        let result = DDCValueScaling.read(current: 300, reportedMax: 255)
        #expect(result.percentage == 100)
        #expect(result.maxToCache == 255)
    }

    @Test("max=100 的显示器读写行为保持不变")
    func max100DisplayUnchanged() {
        let result = DDCValueScaling.read(current: 50, reportedMax: 100)
        #expect(result.percentage == 50)
        #expect(result.maxToCache == 100)
        #expect(DDCValueScaling.write(percentage: 50, maxValue: 100) == 50)
    }

    @Test("写回百分比夹到 0...100")
    func writeClampsPercentageRange() {
        #expect(DDCValueScaling.write(percentage: 200, maxValue: 255) == 255)
        #expect(DDCValueScaling.write(percentage: -50, maxValue: 255) == 0)
    }

    @Test("满量程 65535 时 100% 写回不溢出 UInt16")
    func writeFullScaleUInt16Boundary() {
        #expect(DDCValueScaling.write(percentage: 100, maxValue: 65535) == 65535)
    }
}