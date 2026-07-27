import EditorService
import LumiUI
import SwiftUI
import LumiKernel

public struct BottomEditorCallHierarchyPanelView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var service: EditorService
    public var showsHeader: Bool = true

    public init(service: EditorService, showsHeader: Bool = true) {
        self._service = ObservedObject(wrappedValue: service)
        self.showsHeader = showsHeader
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                header
                Divider()
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(panelTitle)
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)

            Spacer(minLength: 0)

            Button {
                service.panel.performPanelCommand(.closeCallHierarchy)
            } label: {
                Image(systemName: "xmark")
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if service.lsp.callHierarchyProvider.isLoading {
            emptyState(LumiPluginLocalization.string("Loading Call Hierarchy...", bundle: .module), systemImage: "arrow.triangle.branch")
        } else if service.lsp.callHierarchyProvider.rootItem == nil {
            emptyState(LumiPluginLocalization.string("No Call Hierarchy", bundle: .module), systemImage: "point.3.connected.trianglepath.dotted")
        } else {
            HStack(spacing: 0) {
                callHierarchyColumn(title: LumiPluginLocalization.string("Incoming", bundle: .module), calls: service.lsp.callHierarchyProvider.incomingCalls)
                Divider()
                callHierarchyColumn(title: LumiPluginLocalization.string("Outgoing", bundle: .module), calls: service.lsp.callHierarchyProvider.outgoingCalls)
            }
        }
    }

    private var panelTitle: String {
        let count = service.lsp.callHierarchyProvider.incomingCalls.count + service.lsp.callHierarchyProvider.outgoingCalls.count
        return count > 0 ? LumiPluginLocalization.string("Call Hierarchy (\(count))", bundle: .module) : LumiPluginLocalization.string("Call Hierarchy", bundle: .module)
    }

    private func callHierarchyColumn(title: String, calls: [EditorCallHierarchyCall]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.appMicroEmphasized)
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.top, 10)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if calls.isEmpty {
                        emptyState(LumiPluginLocalization.string("Empty", bundle: .module), systemImage: "minus.circle")
                    } else {
                        ForEach(calls) { call in
                            Button {
                                service.navigation.performOpenItem(.callHierarchyItem(call.item))
                            } label: {
                                panelCard(
                                    title: call.item.name,
                                    subtitle: call.item.kindDisplayName,
                                    badge: call.item.fileBadge
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func panelCard(title: String, subtitle: String, badge: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(badge)
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.textPrimary.opacity(0.05))
                    .clipShape(Capsule())
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .appSurface(style: .custom(theme.textPrimary.opacity(0.05)), cornerRadius: 8)
    }

    private func emptyState(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.appTitle)
                .foregroundColor(theme.textTertiary)
            Text(title)
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}
