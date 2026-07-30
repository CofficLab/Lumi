import AppKit
import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// Agent Rules 条目（视图模型）。
///
/// 将磁盘上的 `AgentRuleMetadata` 与其项目路径配对，便于在列表中展示。
private struct AgentRuleEntry: Identifiable {
    let rule: AgentRuleMetadata
    let projectPath: String

    var id: String { rule.id }

    var projectDisplayName: String {
        if projectPath.isEmpty {
            return "Global"
        }
        let url = URL(fileURLWithPath: projectPath)
        return url.lastPathComponent
    }
}

/// Agent Rules 设置视图。
///
/// - 顶部右上角按钮可打开规则目录（`.agent/rules`）。
/// - 下方左侧为规则列表，点击某条规则在右侧展示其详情信息。
@MainActor
public struct AgentRulesSettingsView: View {
    @LumiTheme private var theme

    @State private var entries: [AgentRuleEntry] = []
    @State private var selectedID: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init() {}

    private var selectedEntry: AgentRuleEntry? {
        guard let selectedID else { return nil }
        return entries.first { $0.id == selectedID }
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Agent Rules", bundle: .module),
            subtitle: LumiPluginLocalization.string(
                "View and manage rule documents in .agent/rules directory",
                bundle: .module
            ),
            showHeader: false,
            scrollsContent: false
        ) {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    AppButton("Open Rules Directory", systemImage: "folder", size: .small) {
                        openRulesDirectory()
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
        .task { await reload() }
    }

    // MARK: - Sidebar Header

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Label("\(entries.count) rules", systemImage: "doc.text")
            Spacer()
            AppButton("Refresh", systemImage: "arrow.clockwise", size: .small) {
                Task { await reload() }
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.background)
    }

    // MARK: - Sidebar（规则列表）

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                AppEmptyState(
                    icon: "exclamationmark.triangle",
                    title: error
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entries.isEmpty {
                AppEmptyState(
                    icon: "doc.text",
                    title: "No rules yet"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(entries) { entry in
                            ruleRow(entry)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func ruleRow(_ entry: AgentRuleEntry) -> some View {
        let isSelected = selectedID == entry.id

        return AppListRow(isSelected: isSelected, action: {
            selectedID = entry.id
        }) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 6)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.rule.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)

                        Text(entry.projectDisplayName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }

                    Text(entry.rule.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Detail Pane（规则详情）

    @ViewBuilder
    private var detailPane: some View {
        if let entry = selectedEntry {
            let rule = entry.rule

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AppSettingsSection(title: "Overview") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(rule.title)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(2)

                            Text(rule.description)
                                .font(.callout)
                                .foregroundStyle(theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    AppSettingsSection(title: "Basic Info") {
                        VStack(spacing: 0) {
                            detailRow(title: "Filename", icon: "doc", value: rule.filename)
                            Divider().padding(.vertical, 8)
                            detailRow(title: "Project", icon: "folder", value: entry.projectDisplayName)
                            Divider().padding(.vertical, 8)
                            detailRow(title: "Size", icon: "doc.on.doc", value: rule.formattedFileSize)
                            Divider().padding(.vertical, 8)
                            detailRow(
                                title: "Modified",
                                icon: "clock",
                                value: formattedDate(rule.modifiedAt)
                            )
                            Divider().padding(.vertical, 8)
                            detailRow(title: "File", icon: "doc", value: rule.filePath, monospace: true)
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        } else {
            AppEmptyState(
                icon: "doc.text",
                title: entries.isEmpty ? "No rules yet" : "Select a rule"
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
        errorMessage = nil
        defer { isLoading = false }

        // 当前项目路径（暂时为空，支持全局规则）
        let projectPath = ""
        let rulesDirectory = getRulesDirectory(for: projectPath)

        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: rulesDirectory.path()) {
            entries = []
            return
        }

        do {
            let rules = try await AgentRulesService.shared.listRules(projectPath: projectPath)
            entries = rules.map { AgentRuleEntry(rule: $0, projectPath: projectPath) }
            if selectedID == nil {
                selectedID = entries.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
            entries = []
        }
    }

    private func getRulesDirectory(for projectPath: String) -> URL {
        if projectPath.isEmpty {
            // Global rules directory
            let home = FileManager.default.homeDirectoryForCurrentUser
            return home.appendingPathComponent(".agent/rules")
        }
        let projectURL = URL(fileURLWithPath: projectPath)
        return projectURL.appendingPathComponent(".agent/rules")
    }

    // MARK: - Formatting

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: - Actions

    private func openRulesDirectory() {
        let projectPath = ""
        let url = getRulesDirectory(for: projectPath)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }
}
