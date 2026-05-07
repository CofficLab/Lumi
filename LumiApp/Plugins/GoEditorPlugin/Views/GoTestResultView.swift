import SwiftUI
import MagicKit

/// Go 测试结果面板视图
///
/// 显示 go test 的结果列表。
struct GoTestResultView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var buildManager: GoBuildManager

    var body: some View {
        VStack(spacing: 0) {
            statusBar

            Divider()

            if buildManager.state == .testing {
                loadingState
            } else if buildManager.testEvents.isEmpty {
                emptyState
            } else {
                testList
            }
        }
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "testtube.2")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(
                    themeVM.activeAppTheme.workspaceSecondaryTextColor()
                )

            if buildManager.state == .testing {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text(String(localized: "Testing...", table: "GoEditor"))
                    .font(.system(size: 11, weight: .medium))
            } else {
                let passed = buildManager.testEvents.filter { $0.status == .pass }.count
                let failed = buildManager.testEvents.filter { $0.status == .fail }.count
                let skipped = buildManager.testEvents.filter { $0.status == .skip }.count

                if failed > 0 {
                    Text("\(passed) \(String(localized: "passed", table: "GoEditor")), \(failed) \(String(localized: "failed", table: "GoEditor")), \(skipped) \(String(localized: "skipped", table: "GoEditor"))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppUI.Color.semantic.error)
                } else if !buildManager.testEvents.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppUI.Color.semantic.success)
                        Text("\(passed) \(String(localized: "passed", table: "GoEditor"))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppUI.Color.semantic.success)
                    }
                }
            }

            Spacer()

            if buildManager.lastBuildDuration > 0 {
                Text(String(format: "%.1fs", buildManager.lastBuildDuration))
                    .font(.system(size: 10))
                    .foregroundColor(
                        themeVM.activeAppTheme.workspaceTertiaryTextColor()
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05)
        )
    }

    // MARK: - 测试列表

    private var testList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(buildManager.testEvents) { event in
                    testEventRow(event)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 测试事件行

    private func testEventRow(_ event: GoTestOutputParser.TestEvent) -> some View {
        HStack(spacing: 6) {
            Image(systemName: event.status == .pass ? "checkmark.circle.fill" : event.status == .fail ? "xmark.circle.fill" : "forward.circle")
                .font(.system(size: 10))
                .foregroundColor(
                    event.status == .pass
                        ? AppUI.Color.semantic.success
                        : event.status == .fail
                            ? AppUI.Color.semantic.error
                            : themeVM.activeAppTheme.workspaceTertiaryTextColor()
                )
                .frame(width: 14)

            Text(event.test)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(
                    themeVM.activeAppTheme.workspaceTextColor()
                )

            Spacer()

            if let elapsed = event.elapsed {
                Text(String(format: "%.2fs", elapsed))
                    .font(.system(size: 10))
                    .foregroundColor(
                        themeVM.activeAppTheme.workspaceTertiaryTextColor()
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    // MARK: - 加载状态

    private var loadingState: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text(String(localized: "Running tests...", table: "GoEditor"))
                .font(.system(size: 11))
                .foregroundColor(
                    themeVM.activeAppTheme.workspaceSecondaryTextColor()
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "testtube.2")
                .font(.system(size: 20, weight: .thin))
                .foregroundColor(
                    themeVM.activeAppTheme.workspaceTertiaryTextColor()
                )
            Text(String(localized: "Run go test to see results", table: "GoEditor"))
                .font(.system(size: 11))
                .foregroundColor(
                    themeVM.activeAppTheme.workspaceSecondaryTextColor()
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
