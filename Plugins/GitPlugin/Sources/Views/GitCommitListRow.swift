import SwiftUI
import LumiUI
import LumiKernel

/// Shared Git commit row used by the panel sidebar and compact status bar popover.
public struct GitCommitListRow: View {
    public enum Style {
        case panel
        case compact
    }

    public let commit: GitCommitLog
    public let isSelected: Bool
    public var isUnpushed: Bool = false
    public var style: Style = .panel
    public var action: (() -> Void)? = nil

    public var body: some View {
        AppListRow(isSelected: isSelected, action: { action?() }) {
            HStack(alignment: .top, spacing: 8) {
                indicator

                VStack(alignment: .leading, spacing: style == .panel ? 3 : 2) {
                    HStack(alignment: .top, spacing: 4) {
                        Text(commit.message)
                            .font(.system(size: style == .panel ? 12 : 11, weight: isSelected ? .medium : .regular))
                            .foregroundColor(messageColor)
                            .lineLimit(2)

                        Spacer()

                        if isUnpushed {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                                .help(LumiPluginLocalization.string("Not pushed to remote repository", bundle: .module))
                        }
                    }

                    HStack(spacing: 4) {
                        Text(commit.author)
                            .lineLimit(1)
                        Text(verbatim: LumiPluginLocalization.string("·", bundle: .module))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(relativeTimeString(from: commit.date))
                            .lineLimit(1)
                    }
                    .font(.system(size: 10))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                    Text(commit.hash.prefix(7))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.vertical, style == .panel ? 2 : 2)
                .padding(.trailing, 0)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var indicator: some View {
        switch style {
        case .panel:
            VStack(spacing: 0) {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)

                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 8)
        case .compact:
            Circle()
                .fill(isSelected ? Color(hex: "7C6FFF") : Color.secondary.opacity(0.5))
                .frame(width: 7, height: 7)
                .padding(.top, 4)
        }
    }

    private var messageColor: Color {
        switch style {
        case .panel:
            let base = Color.adaptive(light: "1C1C1E", dark: "FFFFFF")
            return isSelected ? base : base.opacity(0.85)
        case .compact:
            return .primary
        }
    }

    private func relativeTimeString(from dateString: String) -> String {
        for formatter in DateParseHelper.formatHandlers {
            if let date = formatter.date(from: dateString) {
                return date.relativeTimeString
            }
        }

        if dateString.count >= 10 {
            return String(dateString.prefix(10))
        }
        return dateString
    }
}
