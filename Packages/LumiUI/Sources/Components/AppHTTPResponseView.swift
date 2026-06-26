import AppKit
import SwiftUI

public struct AppHTTPResponseView: View {
    public enum BodyDisplayMode: String, CaseIterable, Identifiable {
        case pretty
        case raw

        public var id: String { rawValue }
    }

    @LumiTheme private var theme

    private let response: AppHTTPResponse
    private let title: String?
    private let showsHeader: Bool
    private let bodyMinHeight: CGFloat

    @State private var bodyDisplayMode: BodyDisplayMode = .pretty

    public init(
        response: AppHTTPResponse,
        title: String? = nil,
        showsHeader: Bool = true,
        bodyMinHeight: CGFloat = 220
    ) {
        self.response = response
        self.title = title
        self.showsHeader = showsHeader
        self.bodyMinHeight = bodyMinHeight
    }

    public init(
        statusCode: Int?,
        body: String?,
        title: String? = nil,
        showsHeader: Bool = true,
        bodyMinHeight: CGFloat = 220
    ) {
        self.init(
            response: AppHTTPResponse(statusCode: statusCode, body: body),
            title: title,
            showsHeader: showsHeader,
            bodyMinHeight: bodyMinHeight
        )
    }

    private var resolvedTitle: String {
        title ?? LumiUILocalization.string("HTTP Response")
    }

    private var supportsPrettyJSON: Bool {
        AppHTTPResponse.isValidJSON(response.trimmedBody)
    }

    private var displayedBody: String {
        let usePretty = supportsPrettyJSON && bodyDisplayMode == .pretty
        return response.displayBody(pretty: usePretty)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
            if showsHeader {
                header
            }

            if let statusCode = response.statusCode {
                statusBar(statusCode: statusCode)
            }

            if response.hasBody {
                bodySection
            } else {
                emptyBodyPlaceholder
            }
        }
        .padding(AppUI.Spacing.md)
        .onAppear {
            bodyDisplayMode = supportsPrettyJSON ? .pretty : .raw
        }
        .onChange(of: response.trimmedBody) { _, _ in
            bodyDisplayMode = supportsPrettyJSON ? .pretty : .raw
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: AppUI.Spacing.sm) {
            Text(verbatim: resolvedTitle)
                .font(AppUI.Typography.callout)
                .fontWeight(.semibold)
                .foregroundColor(theme.textPrimary)

            Spacer()

            AppIconButton(systemImage: "doc.on.doc", size: .compact) {
                copyResponse()
            }
            .help(LumiUILocalization.string("Copy"))
        }
    }

    @ViewBuilder
    private func statusBar(statusCode: Int) -> some View {
        HStack(spacing: AppUI.Spacing.sm) {
            statusBadge(statusCode: statusCode)

            Text(AppHTTPResponse.statusPhrase(for: statusCode))
                .font(AppUI.Typography.caption1)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func statusBadge(statusCode: Int) -> some View {
        let tone = AppHTTPStatusTone.tone(for: statusCode)
        Text("\(statusCode)")
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(statusForeground(tone: tone))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: AppUI.Radius.sm, style: .continuous)
                    .fill(statusBackground(tone: tone))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppUI.Radius.sm, style: .continuous)
                    .stroke(statusBorder(tone: tone), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: AppUI.Spacing.sm) {
            HStack(spacing: AppUI.Spacing.sm) {
                Text(verbatim: LumiUILocalization.string("Response Body"))
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(theme.textSecondary)

                Spacer(minLength: 0)

                if supportsPrettyJSON {
                    Picker("", selection: $bodyDisplayMode) {
                        Text(verbatim: LumiUILocalization.string("Pretty"))
                            .tag(BodyDisplayMode.pretty)
                        Text(verbatim: LumiUILocalization.string("Raw"))
                            .tag(BodyDisplayMode.raw)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 132)
                }
            }

            ScrollView(.vertical, showsIndicators: true) {
                Text(displayedBody)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(AppUI.Spacing.sm)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: bodyMinHeight)
            .appSurface(style: .subtle, cornerRadius: AppUI.Radius.sm)
        }
    }

    @ViewBuilder
    private var emptyBodyPlaceholder: some View {
        Text(verbatim: LumiUILocalization.string("No response body"))
            .font(AppUI.Typography.caption1)
            .foregroundColor(theme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: bodyMinHeight, alignment: .topLeading)
            .appSurface(style: .subtle, cornerRadius: AppUI.Radius.sm)
            .padding(.top, AppUI.Spacing.xs)
    }

    private func statusForeground(tone: AppHTTPStatusTone) -> Color {
        switch tone {
        case .success:
            theme.success
        case .redirect, .informational:
            theme.primary
        case .clientError, .serverError:
            theme.error
        case .unknown:
            theme.textSecondary
        }
    }

    private func statusBackground(tone: AppHTTPStatusTone) -> Color {
        statusForeground(tone: tone).opacity(0.12)
    }

    private func statusBorder(tone: AppHTTPStatusTone) -> Color {
        statusForeground(tone: tone).opacity(0.28)
    }

    private func copyResponse() {
        let text = response.copyText.trimmingCharacters(in: .whitespacesAndNewlines)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text.isEmpty ? "-" : text, forType: .string)
    }
}

#Preview("Error Response") {
    AppHTTPResponseView(
        statusCode: 429,
        body: #"{"error":{"message":"Rate limit exceeded","type":"rate_limit_error"}}"#
    )
    .frame(width: 520, height: 320)
    .padding()
    .background(Color.gray.opacity(0.15))
}

#Preview("Success Response") {
    AppHTTPResponseView(
        statusCode: 200,
        body: #"{"id":"chatcmpl-123","choices":[{"message":{"content":"Hello"}}]}"#
    )
    .frame(width: 520, height: 320)
    .padding()
    .background(Color.gray.opacity(0.15))
}
