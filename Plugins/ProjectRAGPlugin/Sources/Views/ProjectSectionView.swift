import LumiKernel
import LumiUI
import SwiftUI

@MainActor
struct RAGSettingsProjectSectionView: View {
    let project: RAGTrackedProject
    let statusesByPath: [String: RAGIndexStatus]
    let progressByPath: [String: RAGIndexProgressEvent]
    let isLoading: Bool

    var body: some View {
        projectSection(project)
    }

    // MARK: - Project Section

    @ViewBuilder
    private func projectSection(_ project: RAGTrackedProject) -> some View {
        AppSettingSection(
            title: project.name,
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: "Path",
                    icon: "folder"
                ) {
                    Text(project.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(project.path)
                }
                Divider().padding(.vertical, 8)

                statusRow(for: project)
                Divider().padding(.vertical, 8)

                if let status = statusesByPath[project.path] {
                    AppSettingRow(
                        title: "Last Indexed",
                        icon: "clock"
                    ) {
                        Text(relativeDate(status.lastIndexedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider().padding(.vertical, 8)

                    AppSettingRow(
                        title: "Files",
                        icon: "doc"
                    ) {
                        Text("\(status.fileCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider().padding(.vertical, 8)

                    AppSettingRow(
                        title: "Chunks",
                        icon: "square.stack.3d.up"
                    ) {
                        Text("\(status.chunkCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider().padding(.vertical, 8)

                    AppSettingRow(
                        title: "Embedding",
                        description: "dim \(status.embeddingDimension)",
                        icon: "brain.head.profile"
                    ) {
                        Text(status.embeddingModel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if isLoading {
                    AppSettingRow(
                        title: "Status",
                        icon: "ellipsis.circle"
                    ) {
                        Text("Loading…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    AppSettingRow(
                        title: "Status",
                        icon: "circle.dashed"
                    ) {
                        Text("Not indexed yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let progress = progressByPath[project.path],
                   progress.totalFiles > 0,
                   !progress.isFinished {
                    Divider().padding(.vertical, 8)
                    AppSettingRow(
                        title: "Progress",
                        icon: "progress.indicator"
                    ) {
                        HStack(spacing: 8) {
                            ProgressView(value: Double(progress.scannedFiles), total: Double(progress.totalFiles))
                                .frame(maxWidth: 160)
                            Text("\(progress.scannedFiles)/\(progress.totalFiles)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Status Row

    @ViewBuilder
    private func statusRow(for project: RAGTrackedProject) -> some View {
        if let progress = progressByPath[project.path], !progress.isFinished {
            AppSettingRow(
                title: "Status",
                icon: "arrow.triangle.2.circlepath"
            ) {
                statusPill(text: "Indexing", color: .blue, spinning: true)
            }
        } else if let status = statusesByPath[project.path] {
            if status.isStale {
                AppSettingRow(
                    title: "Status",
                    icon: "exclamationmark.triangle.fill"
                ) {
                    statusPill(text: "Outdated", color: .orange, spinning: false)
                }
            } else {
                AppSettingRow(
                    title: "Status",
                    icon: "checkmark.circle.fill"
                ) {
                    statusPill(text: "Up to Date", color: .green, spinning: false)
                }
            }
        } else if isLoading {
            AppSettingRow(
                title: "Status",
                icon: "ellipsis.circle"
            ) {
                statusPill(text: "Loading…", color: .secondary, spinning: false)
            }
        } else {
            AppSettingRow(
                title: "Status",
                icon: "circle.dashed"
            ) {
                statusPill(text: "Not Indexed", color: .secondary, spinning: false)
            }
        }
    }

    // MARK: - Status Pill

    @ViewBuilder
    private func statusPill(text: String, color: Color, spinning: Bool) -> some View {
        HStack(spacing: 4) {
            if spinning {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.6)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(color.opacity(0.12))
        )
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
