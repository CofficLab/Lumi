import AppKit
import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// 记忆条目（视图模型）。
///
/// 将磁盘上的 `MemoryItem` 与其所属作用域（`MemoryScope`）配对，
/// 便于在列表中展示并区分全局 / 项目级记忆。
private struct MemoryEntry: Identifiable {
    let item: MemoryItem
    let scope: MemoryScope

    var id: String { "\(item.id)|\(scopeKey)" }

    var scopeKey: String {
        switch scope {
        case .global:
            return "global"
        case .project:
            return "project"
        }
    }

    /// 项目目录名（去除末尾的哈希指纹后的人类可读标识）
    var projectDisplayName: String {
        switch scope {
        case .global:
            return "Global"
        case .project(let dirName):
            if let range = dirName.range(of: "_", options: .backwards) {
                return String(dirName[..<range.lowerBound])
            }
            return dirName
        }
    }

    var scopeDescription: String {
        switch scope {
        case .global:
            return "Global"
        case .project:
            return "Project: \(projectDisplayName)"
        }
    }
}

/// Memory 设置视图。
///
/// - 顶部右上角按钮可打开数据库目录（`MemoryPlugin.config.memoryRootURL`）。
/// - 下方左侧为记忆列表，点击某条记忆在右侧展示其详情信息。
@MainActor
public struct MemorySettingsView: View {
    @LumiTheme private var theme

    @State private var entries: [MemoryEntry] = []
    @State private var selectedID: String?
    @State private var isLoading = false

    public init() {}

    private var selectedEntry: MemoryEntry? {
        guard let selectedID else { return nil }
        return entries.first { $0.id == selectedID }
    }

    private var staleThreshold: Int {
        MemoryPlugin.config.staleThresholdDays
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
        .task { await reload() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Label("\(entries.count) memories", systemImage: "brain")
            if let selected = selectedEntry {
                Text("·")
                Text(selected.item.name)
            }
            Spacer()
            AppButton("Refresh", systemImage: "arrow.clockwise", size: .small) {
                Task { await reload() }
            }
            AppButton("Open Data Directory", systemImage: "folder", size: .small) {
                openDataDirectory()
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    // MARK: - Sidebar（记忆列表）

    private var sidebar: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entries.isEmpty {
                AppEmptyState(
                    icon: "brain",
                    title: "No memories yet"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(entries) { entry in
                            memoryRow(entry)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func memoryRow(_ entry: MemoryEntry) -> some View {
        let isSelected = selectedID == entry.id
        let isStale = entry.item.isStale(thresholdDays: staleThreshold)

        return AppListRow(isSelected: isSelected, action: {
            selectedID = entry.id
        }) {
            HStack(spacing: 10) {
                Image(systemName: "brain")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 6)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.item.name)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        scopeBadge(entry)
                        if isStale {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(entry.item.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func scopeBadge(_ entry: MemoryEntry) -> some View {
        Text(entry.scopeKey == "global" ? "G" : "P")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.primary.opacity(0.06), in: Capsule())
    }

    // MARK: - Detail Pane（记忆详情）

    @ViewBuilder
    private var detailPane: some View {
        if let entry = selectedEntry {
            let item = entry.item
            let isStale = item.isStale(thresholdDays: staleThreshold)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AppSettingsSection(title: "Overview") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(item.name)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(2)

                            Text(item.description)
                                .font(.callout)
                                .foregroundStyle(theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    AppSettingsSection(title: "Basic Info") {
                        VStack(spacing: 0) {
                            detailRow(title: "Type", icon: "tag", value: item.type.displayName)
                            Divider().padding(.vertical, 8)
                            detailRow(title: "Scope", icon: "globe", value: entry.scopeDescription)
                            Divider().padding(.vertical, 8)
                            detailRow(
                                title: "Created",
                                icon: "calendar",
                                value: formattedDate(item.createdAt)
                            )
                            Divider().padding(.vertical, 8)
                            detailRow(
                                title: "Updated",
                                icon: "calendar.badge.clock",
                                value: formattedDate(item.updatedAt)
                            )
                            Divider().padding(.vertical, 8)
                            detailRow(
                                title: "Age",
                                icon: "hourglass",
                                value: "\(item.ageInDays) days"
                            )
                            Divider().padding(.vertical, 8)
                            detailRow(
                                title: "Status",
                                icon: "clock",
                                value: isStale ? "Stale (\(item.ageInDays)d)" : "Fresh"
                            )
                            Divider().padding(.vertical, 8)
                            detailRow(title: "File", icon: "doc", value: item.filePath, monospace: true)
                        }
                    }

                    AppSettingsSection(title: "Content") {
                        ScrollView {
                            Text(item.content)
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(theme.textSecondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 260)
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        } else {
            AppEmptyState(
                icon: "brain",
                title: entries.isEmpty ? "No memories yet" : "Select a memory"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        }
    }

    private func detailRow(title: String, icon: String, value: String, monospace: Bool = false) -> some View {
        AppSettingRow(title: title, icon: icon) {
            Text(value)
                .font(monospace ? .system(.callout, design: .monospaced) : .callout)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }

    // MARK: - Data

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        let result = await MemoryStorageService.shared.listAllMemories()
        entries = result.map { MemoryEntry(item: $0.0, scope: $0.1) }
        if selectedID == nil {
            selectedID = entries.first?.id
        }
    }

    // MARK: - Formatting

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: - Actions

    private func openDataDirectory() {
        let url = MemoryPlugin.config.memoryRootURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }
}
