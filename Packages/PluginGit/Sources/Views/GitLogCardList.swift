import AppKit
import LumiUI
import SwiftUI

/// git_log 结果的 commit 卡片列表视图，用于消息列表中的自定义渲染。
struct GitLogCardList: View {
    @LumiTheme private var theme

    let commits: [GitCommitLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ForEach(commits) { commit in
                GitCommitCard(commit: commit)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.success)
            Text("最近 \(commits.count) 次提交")
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
    }
}

/// 单个 commit 卡片：hash + 信息 + 作者 + 日期 + 复制按钮。
private struct GitCommitCard: View {
    @LumiTheme private var theme

    let commit: GitCommitLog
    @State private var copied = false

    var body: some View {
        AppCard(style: .subtle, cornerRadius: 10, showShadow: false, borderIntensity: 0.04) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(theme.success.opacity(0.9))
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(commit.message)
                            .font(.appBody)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(3)
                            .textSelection(.enabled)

                        HStack(spacing: 6) {
                            Text(commit.hash.prefix(7))
                                .font(.appMonoCaption)
                                .foregroundColor(theme.textSecondary)
                                .textSelection(.enabled)

                            Button {
                                copyHash()
                            } label: {
                                Label(
                                    copied ? "已复制" : "复制",
                                    systemImage: copied ? "checkmark" : "doc.on.doc"
                                )
                                .font(.appMicro)
                                .foregroundColor(theme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .help("复制完整 commit 哈希")
                        }

                        HStack(spacing: 6) {
                            Text(commit.author)
                                .font(.appMicro)
                                .foregroundColor(theme.textSecondary)
                            if !commit.date.isEmpty {
                                Text("·")
                                    .foregroundColor(theme.textTertiary)
                                Text(friendlyDate(commit.date))
                                    .font(.appMicro)
                                    .foregroundColor(theme.textTertiary)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func copyHash() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(commit.hash, forType: .string)
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copied = false
        }
    }

    /// ISO 日期 → “MM-dd HH:mm” 的简短格式；解析失败时退回原始前缀。
    private func friendlyDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else {
            return String(iso.prefix(10))
        }
        let output = DateFormatter()
        output.dateFormat = "MM-dd HH:mm"
        output.locale = Locale(identifier: "en_US_POSIX")
        return output.string(from: date)
    }
}

extension GitCommitLog: Identifiable {
    public var id: String { hash }
}