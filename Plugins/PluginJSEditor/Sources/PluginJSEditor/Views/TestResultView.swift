import LumiCoreKit
import SwiftUI

public struct TestResultView: View {
    @EnvironmentObject private var themeVM: AppThemeVM
    @ObservedObject var taskManager: JSTaskManager

    public var body: some View {
        VStack(spacing: 0) {
            statusBar
            Divider()
            if taskManager.state == .testing {
                loadingState
            } else if taskManager.testEvents.isEmpty {
                emptyState
            } else {
                testList
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "testtube.2")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())

            if taskManager.state == .testing {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text(String(localized: "Testing...", table: "JSEditor"))
                    .font(.system(size: 11, weight: .medium))
            } else {
                Text(summaryText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(failedCount > 0 ? Color(hex: "FF453A") : Color(hex: "30D158"))
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(themeVM.activeChromeTheme.workspaceTertiaryTextColor().opacity(0.05))
    }

    private var testList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(taskManager.testEvents) { event in
                    testEventRow(event)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func testEventRow(_ event: JSTestEvent) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol(for: event.status))
                .font(.system(size: 10))
                .foregroundColor(color(for: event.status))
                .frame(width: 14)

            Text(event.name)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(themeVM.activeChromeTheme.workspaceTextColor())

            Spacer()

            if let duration = event.duration {
                Text(String(format: "%.2fs", duration))
                    .font(.system(size: 10))
                    .foregroundColor(themeVM.activeChromeTheme.workspaceTertiaryTextColor())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private var loadingState: some View {
        VStack(spacing: 8) {
            ProgressView().scaleEffect(0.8)
            Text(String(localized: "Running tests...", table: "JSEditor"))
                .font(.system(size: 11))
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "testtube.2")
                .font(.system(size: 20, weight: .thin))
                .foregroundColor(themeVM.activeChromeTheme.workspaceTertiaryTextColor())
            Text(String(localized: "Run JS tests to see results", table: "JSEditor"))
                .font(.system(size: 11))
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var passedCount: Int { taskManager.testEvents.filter { $0.status == .passed }.count }
    private var failedCount: Int { taskManager.testEvents.filter { $0.status == .failed }.count }
    private var skippedCount: Int { taskManager.testEvents.filter { $0.status == .skipped }.count }

    private var summaryText: String {
        "\(passedCount) \(String(localized: "passed", table: "JSEditor")), \(failedCount) \(String(localized: "failed", table: "JSEditor")), \(skippedCount) \(String(localized: "skipped", table: "JSEditor"))"
    }

    private func symbol(for status: JSTestEvent.Status) -> String {
        switch status {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "forward.circle"
        case .running: return "circle.dotted"
        }
    }

    private func color(for status: JSTestEvent.Status) -> Color {
        switch status {
        case .passed: return Color(hex: "30D158")
        case .failed: return Color(hex: "FF453A")
        case .skipped, .running: return themeVM.activeChromeTheme.workspaceTertiaryTextColor()
        }
    }
}
