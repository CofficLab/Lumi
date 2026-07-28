import AppKit
import Foundation
import LumiUI
import SwiftUI

@MainActor
public struct HTTPExchangeSettingsView: View {
    private let store: HTTPExchangeStore
    @LumiTheme private var theme

    @State private var records: [HTTPExchangeRecord] = []
    @State private var selectedRecordID: UUID?

    public init(store: HTTPExchangeStore) {
        self.store = store
    }

    private var selectedRecord: HTTPExchangeRecord? {
        guard let selectedRecordID else { return nil }
        return records.first { $0.id == selectedRecordID }
    }

    public var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                header

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 340)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    detailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(minHeight: 560, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: HTTPExchangeStore.didChangeNotification)) { _ in
            reload()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label("\(records.count) HTTP exchanges", systemImage: "arrow.up.arrow.down.circle")
            if let selectedRecord {
                Text("Selected: \(selectedRecord.requestMethod) \(selectedRecord.requestURL)")
                    .lineLimit(1)
            }
            Spacer()
            AppButton("Refresh", systemImage: "arrow.clockwise", size: .small) {
                reload()
            }
            AppButton("Open Data Directory", systemImage: "folder", size: .small) {
                NSWorkspace.shared.open(store.directory)
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            if records.isEmpty {
                AppEmptyState(
                    icon: "arrow.up.arrow.down.circle",
                    title: "No HTTP exchanges"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(records) { record in
                            recordRow(record)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func recordRow(_ record: HTTPExchangeRecord) -> some View {
        let isSelected = selectedRecordID == record.id
        return AppListRow(isSelected: isSelected, action: {
            selectedRecordID = record.id
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(record.requestMethod)
                        .font(.appMicroEmphasized)
                        .foregroundStyle(theme.textPrimary)
                    Text(statusText(for: record))
                        .font(.appMicro)
                        .foregroundStyle(statusColor(for: record))
                    Spacer(minLength: 0)
                    Text(relativeDate(record.startedAt))
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                }

                Text(record.requestURL)
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedRecord {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AppSettingsSection(title: "Overview", subtitle: "Complete locally stored HTTP exchange") {
                        VStack(spacing: 0) {
                            detailRow(title: "Method", icon: "arrow.left.arrow.right", value: selectedRecord.requestMethod)
                            AppSettingsDivider()
                            detailRow(title: "URL", icon: "link", value: selectedRecord.requestURL, monospace: true)
                            AppSettingsDivider()
                            detailRow(title: "Status", icon: "number", value: statusText(for: selectedRecord))
                            AppSettingsDivider()
                            detailRow(title: "Started At", icon: "calendar", value: formattedDate(selectedRecord.startedAt))
                            if let duration = selectedRecord.duration {
                                AppSettingsDivider()
                                detailRow(title: "Duration", icon: "clock", value: String(format: "%.3f s", duration))
                            }
                        }
                    }

                    payloadSection(
                        title: "Request Headers",
                        subtitle: "Raw header fields sent with the request",
                        data: selectedRecord.requestHeadersJSON,
                        fallback: "{}"
                    )
                    payloadSection(
                        title: "Request Body",
                        subtitle: "Original request body bytes (\(byteCount(selectedRecord.requestBody)))",
                        data: selectedRecord.requestBody,
                        fallback: "<empty>"
                    )
                    payloadSection(
                        title: "Request Options",
                        subtitle: "URLRequest transport options captured at send time",
                        data: selectedRecord.requestDetailsJSON,
                        fallback: "{}"
                    )
                    payloadSection(
                        title: "Response Headers",
                        subtitle: "Raw header fields received from the server",
                        data: selectedRecord.responseHeadersJSON,
                        fallback: "<no response headers>"
                    )
                    payloadSection(
                        title: "Response Body",
                        subtitle: "Original response body bytes (\(byteCount(selectedRecord.responseBody)))",
                        data: selectedRecord.responseBody,
                        fallback: "<empty>"
                    )

                    if selectedRecord.errorDescription != nil {
                        AppSettingsSection(title: "Error", subtitle: "Transport or HTTP failure details") {
                            VStack(alignment: .leading, spacing: 8) {
                                if let errorDescription = selectedRecord.errorDescription {
                                    Text(errorDescription)
                                        .foregroundStyle(theme.textPrimary)
                                }
                                if let domain = selectedRecord.errorDomain,
                                   let code = selectedRecord.errorCode {
                                    Text("\(domain) (\(code))")
                                        .font(.appCaption)
                                        .foregroundStyle(theme.textSecondary)
                                }
                                if let details = selectedRecord.errorDetailsJSON {
                                    codeBlock(prettyJSON(details))
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        } else {
            AppEmptyState(
                icon: "doc.text.magnifyingglass",
                title: "Select an HTTP exchange"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func payloadSection(title: String, subtitle: String, data: Data?, fallback: String) -> some View {
        AppSettingsSection(title: title, subtitle: subtitle) {
            codeBlock(data.map(payloadText) ?? fallback)
        }
    }

    private func codeBlock(_ text: String) -> some View {
        ScrollView([.horizontal, .vertical]) {
            Text(text)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .frame(minHeight: 70, maxHeight: 260)
        .background(theme.textSecondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func detailRow(title: String, icon: String, value: String, monospace: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Label(title, systemImage: icon)
                .frame(width: 130, alignment: .leading)
                .foregroundStyle(theme.textSecondary)
            Text(value)
                .font(monospace ? .system(.callout, design: .monospaced) : .appCaption)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func reload() {
        records = store.fetchAll()
        if selectedRecordID == nil || !records.contains(where: { $0.id == selectedRecordID }) {
            selectedRecordID = records.first?.id
        }
    }

    private func statusText(for record: HTTPExchangeRecord) -> String {
        if let statusCode = record.responseStatusCode { return String(statusCode) }
        return record.errorDescription == nil ? "Pending" : "Error"
    }

    private func statusColor(for record: HTTPExchangeRecord) -> Color {
        guard let statusCode = record.responseStatusCode else {
            return record.errorDescription == nil ? theme.textSecondary : .red
        }
        return (200..<300).contains(statusCode) ? .green : .orange
    }

    private func byteCount(_ data: Data?) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(data?.count ?? 0), countStyle: .binary)
    }

    private func payloadText(_ data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let pretty = String(data: prettyData, encoding: .utf8) {
            return pretty
        }
        if let text = String(data: data, encoding: .utf8) { return text }
        return data.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    private func prettyJSON(_ data: Data) -> String {
        payloadText(data)
    }

    private func relativeDate(_ date: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    private func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
