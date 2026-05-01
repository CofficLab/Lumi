import SwiftUI

struct CallHierarchySheetView: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            header
            if !state.semanticProblems.isEmpty {
                Divider()
                semanticContextBanner
            }
            Divider()
            content
        }
        .frame(minWidth: 760, idealWidth: 920, minHeight: 420, idealHeight: 560)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let root = state.callHierarchyProvider.rootItem {
                Image(systemName: root.iconSymbol)
                    .foregroundColor(.accentColor)
                Text(root.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(root.kindDisplayName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                Text("调用层级")
                    .font(.system(size: 14, weight: .semibold))
            }
            Spacer()
            Button("关闭") {
                state.performPanelCommand(.closeCallHierarchy)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var semanticContextBanner: some View {
        if let issue = state.semanticProblems.first(where: { $0.severity != .info }) ?? state.semanticProblems.first {
            let color = color(for: issue.severity)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon(for: issue.severity))
                    .foregroundColor(color)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.title)
                        .font(.system(size: 11, weight: .semibold))
                    Text(issue.message)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button("重新解析") {
                    state.resyncProjectContext()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)
                .disabled(state.isResyncingProjectContext)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(color.opacity(0.06))
        }
    }

    @ViewBuilder
    private var content: some View {
        if state.callHierarchyProvider.isLoading {
            VStack(spacing: 10) {
                ProgressView()
                Text("加载调用层级中...")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.callHierarchyProvider.rootItem == nil {
            VStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text("未找到调用层级信息")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 0) {
                CallHierarchyTreeView(
                    calls: state.callHierarchyProvider.incomingCalls,
                    direction: .incoming
                ) { item in
                    state.performOpenItem(.callHierarchyItem(item))
                }
                Divider()
                CallHierarchyTreeView(
                    calls: state.callHierarchyProvider.outgoingCalls,
                    direction: .outgoing
                ) { item in
                    state.performOpenItem(.callHierarchyItem(item))
                }
            }
        }
    }

    private func icon(for severity: EditorSemanticAvailabilitySeverity) -> String {
        switch severity {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }

    private func color(for severity: EditorSemanticAvailabilitySeverity) -> Color {
        switch severity {
        case .info:
            return .accentColor
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
