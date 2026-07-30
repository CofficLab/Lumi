import Foundation
import SuperLogKit
import os

/// 空闲扫描调度器
///
/// 监听空闲状态变化，当空闲时间超过阈值时触发问题扫描。
/// 扫描策略：先执行本地规则扫描（零成本），再按需执行 LLM 深度分析（有成本）。
public actor IdleScannerService: SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.idle-scanner")
    public static let shared = IdleScannerService()

    // MARK: - Configuration

    /// 触发扫描的最小空闲时间（秒）
    private let idleThreshold: TimeInterval = 5 * 60 // 5 分钟

    /// 两次扫描之间的最小间隔（秒）
    private let scanInterval: TimeInterval = 30 * 60 // 30 分钟

    /// 每日 LLM 深度分析最大次数
    private let maxLLMAnalysisPerDay = 5

    // MARK: - State

    private var lastScanAt: Date = .distantPast
    private var todayLLMAnalysisCount = 0
    private var lastResetDate: Date = .distantPast
    private var isScanning = false

    // MARK: - Dependencies

    private let localRuleScanner = LocalRuleScanner()
    private let deepAnalyzer = DeepIssueAnalyzer.shared

    // MARK: - Public API

    /// 尝试触发扫描（由空闲事件驱动）
    ///
    /// 仅当空闲时间超过阈值且距上次扫描超过间隔时才执行。
    /// - Parameter idleDuration: 当前空闲时长（秒）
    public func tryScan(idleDuration: TimeInterval, projectPath: String) async {
        guard idleDuration >= idleThreshold else { return }
        guard !isScanning else { return }
        guard Date().timeIntervalSince(lastScanAt) >= scanInterval else { return }
        guard !projectPath.isEmpty else { return }

        isScanning = true
        defer { isScanning = false; lastScanAt = Date() }

        let localIssues = localRuleScanner.scan(projectPath: projectPath)
        do {
            try await ProjectIssueStore.shared.replaceIssues(
                projectPath: projectPath,
                source: .localRule,
                with: localIssues
            )
        } catch {
            Self.logger.error("\(Self.t)保存本地规则扫描结果失败: \(error.localizedDescription)")
        }

        resetDailyCounterIfNeeded()
        if todayLLMAnalysisCount < maxLLMAnalysisPerDay,
           await deepAnalyzer.isReady(),
           let llmIssues = await deepAnalyzer.analyze(projectPath: projectPath) {
            do {
                try await ProjectIssueStore.shared.replaceIssues(
                    projectPath: projectPath,
                    source: .llmAnalysis,
                    with: llmIssues
                )
                todayLLMAnalysisCount += 1
            } catch {
                Self.logger.error("\(Self.t)保存LLM分析结果失败: \(error.localizedDescription)")
            }
        }
    }

    /// 手动触发扫描（用户主动请求）
    public func forceScan(projectPath: String) async {
        guard !projectPath.isEmpty else { return }
        guard !isScanning else { return }

        isScanning = true
        defer { isScanning = false; lastScanAt = Date() }

        let localIssues = localRuleScanner.scan(projectPath: projectPath)
        do {
            try await ProjectIssueStore.shared.replaceIssues(
                projectPath: projectPath,
                source: .localRule,
                with: localIssues
            )
        } catch {
            Self.logger.error("\(Self.t)保存本地规则扫描结果失败: \(error.localizedDescription)")
        }

        if await deepAnalyzer.isReady(),
           let llmIssues = await deepAnalyzer.analyze(projectPath: projectPath) {
            do {
                try await ProjectIssueStore.shared.replaceIssues(
                    projectPath: projectPath,
                    source: .llmAnalysis,
                    with: llmIssues
                )
            } catch {
                Self.logger.error("\(Self.t)保存LLM分析结果失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private

    private func resetDailyCounterIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, inSameDayAs: Date()) {
            todayLLMAnalysisCount = 0
            lastResetDate = Date()
        }
    }
}
