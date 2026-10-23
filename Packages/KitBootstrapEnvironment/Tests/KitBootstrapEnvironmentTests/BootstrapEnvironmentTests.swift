import Foundation
import KitBootstrapEnvironment
import Testing

/// 启动失败的呈现逻辑。
///
/// 这些测试锁死一条用户可见的契约：**磁盘空间不足时，宿主必须把它呈现为
/// 「磁盘空间不足」，而不是把插件抛出的原始字符串（"数据库重建失败: 未能完成操作。
/// (SwiftData.SwiftDataError 错误。)"）直接甩给用户**。
///
/// 背景：SwiftData 会把底层 SQLite 失败折叠成 `SwiftDataError code 1` +
/// 空 userInfo，根因（`database or disk is full`）只存在于 CoreData 的统一日志里。
/// 应用自己的错误链拿不到根因，所以宿主只能**主动探测卷容量**并据此归因。
@Suite("启动环境预检与失败归因")
struct BootstrapEnvironmentTests {

    private static let gib: Int64 = 1024 * 1024 * 1024
    private static let mib: Int64 = 1024 * 1024

    // MARK: - 空间阈值判定

    @Test("可用空间充足时判定为 sufficient")
    func sufficientWhenPlentyOfSpace() {
        let verdict = BootstrapEnvironment.evaluate(
            availableBytes: 10 * Self.gib,
            requiredBytes: BootstrapEnvironment.defaultRequiredFreeBytes
        )
        #expect(verdict == .sufficient)
    }

    @Test("可用空间低于阈值时判定为 insufficient，并带出可用值与需求值")
    func insufficientWhenLow() {
        let available = 512 * Self.mib
        let required = 2 * Self.gib
        let verdict = BootstrapEnvironment.evaluate(
            availableBytes: available,
            requiredBytes: required
        )
        #expect(verdict == .insufficient(availableBytes: available, requiredBytes: required))
    }

    @Test("恰好等于阈值算充足，不做过度拦截")
    func boundaryIsSufficient() {
        let required = 2 * Self.gib
        let verdict = BootstrapEnvironment.evaluate(
            availableBytes: required,
            requiredBytes: required
        )
        #expect(verdict == .sufficient)
    }

    @Test("探测不到容量时判定为 unknown，不得据此阻断启动")
    func unknownWhenProbeFails() {
        let verdict = BootstrapEnvironment.evaluate(availableBytes: nil)
        #expect(verdict == .unknown)
    }

    // MARK: - 实际探测

    @Test("已存在的目录能探测到卷可用容量")
    func probeExistingDirectory() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bootstrap-probe-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let bytes = BootstrapEnvironment.availableBytes(at: base)
        #expect(bytes != nil)
        #expect((bytes ?? 0) > 0)
    }

    @Test("目标目录不存在时向上找到最近的存在祖先，不因路径缺失而放弃预检")
    func probeWalksUpToExistingAncestor() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bootstrap-probe-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        // 全新安装时数据目录还不存在
        let missing = base.appendingPathComponent("not-created-yet/deep", isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: missing.path))

        let bytes = BootstrapEnvironment.availableBytes(at: missing)
        #expect(bytes != nil)
        #expect((bytes ?? 0) > 0)
    }

    // MARK: - 失败归因

    @Test("磁盘不足时归因为磁盘空间不足，而不是插件原始报错")
    func classifyInsufficientDiskSpace() {
        let context = BootstrapFailureContext(
            pluginID: "com.coffic.lumi.plugin.goal-task",
            phase: "boot",
            technicalDetail: "GoalTaskPlugin 数据库重建失败: 未能完成操作。(SwiftData.SwiftDataError 错误。)"
        )

        let report = BootstrapFailureClassifier.classify(
            context: context,
            space: .insufficient(availableBytes: 0, requiredBytes: 2 * Self.gib)
        )

        #expect(report.kind == .insufficientDiskSpace(availableBytes: 0, requiredBytes: 2 * Self.gib))
    }

    @Test("磁盘充足时保留插件归属信息与原始报错")
    func classifyWithPluginAttribution() {
        let context = BootstrapFailureContext(
            pluginID: "com.coffic.lumi.plugin.goal-task",
            phase: "boot",
            technicalDetail: "GoalTaskPlugin 数据库重建失败: 未能完成操作。"
        )

        let report = BootstrapFailureClassifier.classify(context: context, space: .sufficient)

        #expect(report.kind == .pluginBootFailed)
        #expect(report.pluginID == "com.coffic.lumi.plugin.goal-task")
        #expect(report.phase == "boot")
        #expect(report.technicalDetail.contains("数据库重建失败"))
    }

    @Test("没有归属信息的错误归为 unknown")
    func classifyUnknown() {
        let context = BootstrapFailureContext(
            pluginID: nil,
            phase: nil,
            technicalDetail: "The operation couldn’t be completed. (SomeDomain error 7.)"
        )

        let report = BootstrapFailureClassifier.classify(context: context, space: .sufficient)

        #expect(report.kind == .unknown)
        #expect(report.pluginID == nil)
        #expect(report.phase == nil)
        #expect(!report.technicalDetail.isEmpty)
    }

    @Test("磁盘不足时技术详情不得丢失")
    func technicalDetailSurvivesDiskClassification() {
        let context = BootstrapFailureContext(
            pluginID: "com.coffic.lumi.plugin.goal-task",
            phase: "boot",
            technicalDetail: "GoalTaskPlugin 数据库重建失败: 未能完成操作。"
        )

        let report = BootstrapFailureClassifier.classify(
            context: context,
            space: .insufficient(availableBytes: 0, requiredBytes: 2 * Self.gib)
        )

        #expect(report.technicalDetail.contains("数据库重建失败"))
        #expect(report.pluginID == "com.coffic.lumi.plugin.goal-task")
    }

    @Test("探测失败时不得把启动失败归因成磁盘不足")
    func unknownSpaceDoesNotBlameDisk() {
        let context = BootstrapFailureContext(
            pluginID: "com.coffic.lumi.plugin.goal-task",
            phase: "boot",
            technicalDetail: "Plugin 'com.coffic.lumi.plugin.goal-task' failed during boot: 崩了"
        )

        let report = BootstrapFailureClassifier.classify(context: context, space: .unknown)

        #expect(report.kind == .pluginBootFailed)
    }

    // MARK: - 字节格式化

    @Test("字节数按 GB/MB 确定性格式化")
    func byteFormatting() {
        #expect(BootstrapByteFormat.string(2 * Self.gib) == "2 GB")
        #expect(BootstrapByteFormat.string(1536 * Self.mib) == "1.5 GB")
        #expect(BootstrapByteFormat.string(512 * Self.mib) == "512 MB")
        #expect(BootstrapByteFormat.string(0) == "0 MB")
    }
}
