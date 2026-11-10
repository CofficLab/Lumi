import SwiftUI

/// 多态状态横幅：loading / success / warning / error / info。
///
/// 覆盖 `AppErrorBanner`（仅 error + retry）之外的状态场景
/// （Cisum 贡献）。
public struct AppStatusBanner: View {
    @LumiTheme private var theme

    public enum Kind {
        case loading
        case success
        case warning
        case error
        case info
    }

    let kind: Kind
    let title: Text
    let message: Text?

    public init(kind: Kind, title: LocalizedStringKey, message: LocalizedStringKey? = nil) {
        self.kind = kind
        self.title = Text(title)
        self.message = message.map { Text($0) }
    }

    public init(kind: Kind, title: String, message: String? = nil) {
        self.kind = kind
        self.title = Text(title)
        self.message = message.map(Text.init)
    }

    public var body: some View {
        HStack(spacing: 12) {
            if kind == .loading {
                ProgressView()
                    .scaleEffect(0.9)
            } else {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                title
                    .font(AppUI.Typography.bodyEmphasized)
                    .foregroundColor(theme.textPrimary)
                if let message {
                    message
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(theme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(AppUI.Spacing.md)
        .appSurface(
            style: .custom(theme.elevatedSurface.opacity(0.86)),
            cornerRadius: 8,
            borderColor: tint.opacity(0.18),
            lineWidth: 1
        )
    }

    private var tint: Color {
        switch kind {
        case .loading, .info: theme.info
        case .success: theme.success
        case .warning: theme.warning
        case .error: theme.error
        }
    }

    private var icon: String {
        switch kind {
        case .loading: "progress.indicator"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        case .info: "info.circle.fill"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        AppStatusBanner(kind: .info, title: "Info", message: "A gentle notice")
        AppStatusBanner(kind: .success, title: "Done", message: "Everything worked")
        AppStatusBanner(kind: .warning, title: "Heads up", message: "Something needs attention")
        AppStatusBanner(kind: .error, title: "Failed", message: "Something went wrong")
        AppStatusBanner(kind: .loading, title: "Working…", message: "Please wait")
    }
    .padding()
    .frame(width: 320)
}
