import LumiUI
import SwiftUI

private typealias L = MindMapLocalization

/// 项目内思维导图浏览器：直接展示当前项目的任务列表。
public struct MindMapRailView: View {
    @ObservedObject private var store: MindMapStore
    @LumiTheme private var theme

    init(store: MindMapStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            AppToolbarContainer(
                height: 40,
                backgroundStyle: .panel,
                padding: EdgeInsets(
                    top: DesignTokens.Spacing.sm,
                    leading: DesignTokens.Spacing.md,
                    bottom: DesignTokens.Spacing.sm,
                    trailing: DesignTokens.Spacing.md
                )
            ) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    AppToolbarTitleLabel(title: L.string("Mind Maps"))
                    AppTag("\(store.projectMaps.count)", style: .subtle)
                    Spacer(minLength: 0)
                    AppIconButton(systemImage: "arrow.clockwise", action: store.reload)
                        .accessibilityLabel(L.string("Refresh"))
                        .help(L.string("Refresh"))
                }
            }
            .borderBottom()

            if store.projectStorageDirectory == nil {
                AppEmptyState(
                    icon: "folder",
                    title: L.string("Open a project to enable project-local storage.")
                )
            } else if store.projectMaps.isEmpty {
                AppEmptyState(
                    icon: "brain.head.profile",
                    title: L.string("Ask the Agent to create a mind map.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignTokens.Spacing.xs) {
                        ForEach(store.projectMaps) { map in
                            mapRow(map)
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                }
            }

            if store.projectStorageDirectory != nil {
                Divider()
                AppButton(
                    L.string("New Mind Map"),
                    systemImage: "plus",
                    style: .ghost,
                    size: .small
                ) {
                    _ = store.createMindMap(
                        title: L.string("New Mind Map"),
                        rootText: L.string("Central Topic"),
                        direction: .bilateral,
                        scope: .project
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.Spacing.sm)
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func mapRow(_ map: MindMap) -> some View {
        AppListRow(
            isSelected: store.selectedMapId == map.id,
            action: { try? store.selectMindMap(id: map.id, scope: .project) }
        ) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(theme.primary.opacity(0.10))
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.primary)
                }
                .frame(width: 34, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(map.title)
                        .font(.appBodyEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text(L.format("%lld nodes", Int64(map.nodes.count)))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                store.deleteMindMap(id: map.id, scope: .project)
            } label: {
                Label(L.string("Delete"), systemImage: "trash")
            }
        }
    }
}

#Preview {
    MindMapRailView(store: MindMapStore.shared)
        .frame(width: 280, height: 500)
}
