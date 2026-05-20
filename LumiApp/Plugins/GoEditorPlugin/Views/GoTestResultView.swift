import SwiftUI
import GoEditorCore

/// Go 测试结果面板视图
///
/// 显示 go test 的结果列表。
struct GoTestResultView: View {
    @EnvironmentObject private var themeVM: AppThemeVM
    @ObservedObject var testManager: GoTestManager

    var body: some View {
        VStack(spacing: 0) {
            statusBar

            Divider()

            if testManager.state == .testing {
                loadingState
            } else if testManager.testEvents.isEmpty {
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

            if testManager.state == .testing {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text(String(localized: "Testing...", table: "GoEditor"))
                    .font(.system(size: 11, weight: .medium))
            } else {
                let passed = testManager.passedCount
                let failed = testManager.failedCount
                let skipped = testManager.skippedCount

                if failed > 0 {
                    Text("\(passed) \(String(localized: "passed", table: "GoEditor")), \(failed) \(String(localized: "failed", table: "GoEditor")), \(skipped) \(String(localized: "skipped", table: "GoEditor"))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "FF453A"))
                } else if !testManager.testEvents.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "30D158"))
                        Text("\(passed) \(String(localized: "passed", table: "GoEditor"))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "30D158"))
                    }
                }
            }

            Spacer()

            if testManager.lastTestDuration > 0 {
                Text(String(format: "%.1fs", testManager.lastTestDuration))
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
                ForEach(testManager.testEvents) { event in
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
                        ? Color(hex: "30D158")
                        : event.status == .fail
                            ? Color(hex: "FF453A")
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
