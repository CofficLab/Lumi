import AppKit
import Foundation
import LumiUI
import SwiftUI

/// MiniMax 视频生成记录的设置视图
@MainActor
public struct VideoRecordsSettingsView: View {
    private let store: MiniMaxVideoRecordStore
    @LumiTheme private var theme

    @State private var records: [MiniMaxVideoRecordDTO] = []
    @State private var isLoading = true
    @State private var isReloading = false
    @State private var isLoadingMore = false
    @State private var hasMoreRecords = true
    @State private var selectedRecordID: String?

    private let pageSize = 40

    init(store: MiniMaxVideoRecordStore) {
        self.store = store
    }

    private var selectedRecord: MiniMaxVideoRecordDTO? {
        guard let selectedRecordID else { return nil }
        return records.first { $0.id == selectedRecordID }
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: "Video History",
            subtitle: "MiniMax video generation records",
            showHeader: false,
            scrollsContent: false
        ) {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Label("\(records.count) records", systemImage: "video.circle")
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                    AppButton("Refresh", systemImage: "arrow.clockwise", size: .small) {
                        Task { await reloadAsync() }
                    }
                    AppButton("Open Data Directory", systemImage: "folder", size: .small) {
                        NSWorkspace.shared.open(store.directory)
                    }
                }

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 340)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    detailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .task {
            await reloadAsync()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            if isLoading && records.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text(LumiPluginLocalization.string("Loading...", bundle: .module))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if records.isEmpty {
                AppEmptyState(
                    icon: "video.slash",
                    title: "No video records"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(records) { record in
                            recordRow(record)
                                .onAppear {
                                    if record.id == records.last?.id {
                                        Task { await loadMoreAsync() }
                                    }
                                }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)

                if isLoadingMore {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.bottom, 8)
                }
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func recordRow(_ record: MiniMaxVideoRecordDTO) -> some View {
        let isSelected = selectedRecordID == record.id
        return AppListRow(isSelected: isSelected, action: {
            selectedRecordID = record.id
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(statusEmoji(record.status))
                        .font(.appMicro)
                    Text(record.model)
                        .font(.appMicroEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(formattedDate(record.createdAt))
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                }

                Text(record.prompt)
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedRecord {
            detailScroll {
                AppSettingsSection(title: "Video Info", subtitle: "Generation parameters and result") {
                    VStack(spacing: 0) {
                        detailRow(title: "Status", icon: statusEmoji(selectedRecord.status), value: selectedRecord.status)
                        AppSettingsDivider()
                        detailRow(title: "Model", icon: "cpu", value: selectedRecord.model)
                        AppSettingsDivider()
                        detailRow(title: "Duration", icon: "clock", value: "\(selectedRecord.duration)s")
                        AppSettingsDivider()
                        detailRow(title: "Resolution", icon: "aspectratio", value: selectedRecord.resolution)
                        AppSettingsDivider()
                        detailRow(title: "Created At", icon: "calendar", value: formattedDate(selectedRecord.createdAt))
                        if let completedAt = selectedRecord.completedAt {
                            AppSettingsDivider()
                            let elapsed = completedAt.timeIntervalSince(selectedRecord.createdAt)
                            detailRow(title: "Duration", icon: "hourglass", value: String(format: "%.1fs", elapsed))
                        }
                    }
                }

                AppSettingsSection(title: "Prompt", subtitle: "Video generation prompt") {
                    Text(selectedRecord.prompt)
                        .font(.appBody)
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }

                if let downloadURL = selectedRecord.downloadURL, let url = URL(string: downloadURL) {
                    AppSettingsSection(title: "Download", subtitle: "Video file link") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundStyle(theme.textSecondary)
                                Link(destination: url) {
                                    Text(selectedRecord.fileName ?? "video.mp4")
                                        .lineLimit(1)
                                }
                                Spacer()
                                if let byteCount = selectedRecord.byteCount {
                                    Text(formatByteCount(byteCount))
                                        .font(.appMicro)
                                        .foregroundStyle(theme.textSecondary)
                                }
                            }

                            if let expiresAt = selectedRecord.downloadURLExpiresAt {
                                if expiresAt > Date() {
                                    let remaining = Int(expiresAt.timeIntervalSince(Date()) / 3600)
                                    Text("Expires in ~\(remaining) hours")
                                        .font(.appMicro)
                                        .foregroundStyle(.orange)
                                } else {
                                    Text(LumiPluginLocalization.string("Link expired", bundle: .module))
                                        .font(.appMicro)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if let errorMessage = selectedRecord.errorMessage {
                    AppSettingsSection(title: LumiPluginLocalization.string("Error", bundle: .module), subtitle: "Generation failed") {
                        Text(errorMessage)
                            .font(.appBody)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                }

                AppSettingsSection(title: "Options", subtitle: "Generation options") {
                    VStack(spacing: 0) {
                        detailRow(title: "Prompt Optimizer", icon: "wand.and.stars", value: selectedRecord.promptOptimizer ? "Enabled" : "Disabled")
                        AppSettingsDivider()
                        detailRow(title: "Fast Pretreatment", icon: "bolt", value: selectedRecord.fastPretreatment ? "Enabled" : "Disabled")
                        AppSettingsDivider()
                        detailRow(title: "AIGC Watermark", icon: "drop", value: selectedRecord.aigcWatermark ? "Enabled" : "Disabled")
                    }
                }

                if let taskID = selectedRecord.taskID {
                    AppSettingsSection(title: "Task ID", subtitle: "MiniMax task identifier") {
                        Text(taskID)
                            .font(.appMicro)
                            .monospaced()
                            .foregroundStyle(theme.textSecondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                }
            }
        } else {
            AppEmptyState(
                icon: "doc.text.magnifyingglass",
                title: "Select a video record"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detailScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detailRow(title: String, icon: String, value: String, monospace: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                Text(value)
                    .font(.appCaption)
                    .monospaced(monospace)
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    // MARK: - Data Loading

    private func reloadAsync() async {
        isReloading = true
        defer { isReloading = false }

        let loaded = await store.fetchPage(limit: pageSize, beforeID: nil)
        records = loaded
        hasMoreRecords = loaded.count >= pageSize
        selectedRecordID = loaded.first?.id
        isLoading = false
    }

    private func loadMoreAsync() async {
        guard !isLoadingMore, hasMoreRecords, let lastID = records.last?.id else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let loaded = await store.fetchPage(limit: pageSize, beforeID: lastID)
        if loaded.isEmpty {
            hasMoreRecords = false
        } else {
            records.append(contentsOf: loaded)
            hasMoreRecords = loaded.count >= pageSize
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func statusEmoji(_ status: String) -> String {
        switch status {
        case "success": return "✅"
        case "failed": return "❌"
        case "cancelled": return "🚫"
        case "generating": return "⏳"
        case "pending": return "🕐"
        default: return "❓"
        }
    }

    private func formatByteCount(_ byteCount: Int64) -> String {
        if byteCount < 1024 {
            return "\(byteCount) B"
        } else if byteCount < 1024 * 1024 {
            return String(format: "%.1f KB", Double(byteCount) / 1024)
        } else {
            return String(format: "%.1f MB", Double(byteCount) / (1024 * 1024))
        }
    }
}
