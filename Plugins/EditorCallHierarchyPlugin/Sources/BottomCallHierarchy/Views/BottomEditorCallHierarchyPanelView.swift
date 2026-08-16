import LumiUI
import SwiftUI
import KernelLumi

public struct BottomEditorCallHierarchyPanelView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var viewModel: BottomCallHierarchyViewModel
    public var showsHeader: Bool = true

    public init(viewModel: BottomCallHierarchyViewModel, showsHeader: Bool = true) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
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
        .onAppear {
            viewModel.prepareFromCursor()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(panelTitle)
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)

            Spacer(minLength: 0)

            Button {
                viewModel.close()
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
        if viewModel.state.isLoading {
            emptyState(LumiPluginLocalization.string("Loading Call Hierarchy...", bundle: .module), systemImage: "arrow.triangle.branch")
        } else if viewModel.state.root == nil {
            emptyState(LumiPluginLocalization.string("No Call Hierarchy", bundle: .module), systemImage: "point.3.connected.trianglepath.dotted")
        } else {
            HStack(spacing: 0) {
                callHierarchyColumn(title: LumiPluginLocalization.string("Incoming", bundle: .module), calls: viewModel.state.incoming)
                Divider()
                callHierarchyColumn(title: LumiPluginLocalization.string("Outgoing", bundle: .module), calls: viewModel.state.outgoing)
            }
        }
    }

    private var panelTitle: String {
        let count = viewModel.state.incoming.count + viewModel.state.outgoing.count
        return count > 0 ? LumiPluginLocalization.string("Call Hierarchy (\(count))", bundle: .module) : LumiPluginLocalization.string("Call Hierarchy", bundle: .module)
    }

    private func callHierarchyColumn(title: String, calls: [EditorCallHierarchyEdge]) -> some View {
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
                                viewModel.open(call.node)
                            } label: {
                                panelCard(
                                    title: call.node.name,
                                    subtitle: kindDisplayName(call.node.kind),
                                    badge: call.node.uri.lastPathComponent
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

    private func kindDisplayName(_ kind: EditorDocumentSymbolKind) -> String {
        switch kind {
        case .function: return LumiPluginLocalization.string("Function", bundle: .module)
        case .method: return LumiPluginLocalization.string("Method", bundle: .module)
        case .constructor: return LumiPluginLocalization.string("Initializer", bundle: .module)
        case .class: return LumiPluginLocalization.string("Class", bundle: .module)
        case .interface: return LumiPluginLocalization.string("Protocol", bundle: .module)
        case .struct: return LumiPluginLocalization.string("Structure", bundle: .module)
        case .enum: return LumiPluginLocalization.string("Enumeration", bundle: .module)
        case .enumMember: return LumiPluginLocalization.string("Case", bundle: .module)
        default: return LumiPluginLocalization.string("Symbol", bundle: .module)
        }
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
