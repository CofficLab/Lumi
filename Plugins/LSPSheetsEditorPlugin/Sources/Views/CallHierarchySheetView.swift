import EditorService
import LumiUI
import LSPCallHierarchyEditorPlugin
import SwiftUI

/// 调用层级 Sheet 内容视图。
///
/// 用于承载 `LSPCallHierarchyEditorPlugin` 提供的调用层级数据，并将 incoming/outgoing calls
/// 分栏展示出来。该视图自身不请求 LSP 数据，只读取 `EditorState.callHierarchyProvider` 中的状态；
/// 打开、关闭和跳转行为通过 `EditorState` 的 panel/open item 命令回写给编辑器内核。
public struct CallHierarchySheetView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var state: EditorState

    public var body: some View {
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
                    .foregroundColor(theme.primary)
                Text(root.name)
                    .font(.appCallout)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Text(root.kindDisplayName)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            } else {
                Text(String(localized: "调用层级", table: "LSPSheetsEditor"))
                    .font(.appCallout)
                    .foregroundColor(theme.textPrimary)
            }
            Spacer()
            Button(String(localized: "关闭", table: "LSPSheetsEditor")) {
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
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.textPrimary)
                    Text(issue.message)
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(String(localized: "重新解析", table: "LSPSheetsEditor")) {
                    state.resyncProjectContext()
                }
                .buttonStyle(.plain)
                .font(.appMicroEmphasized)
                .foregroundColor(theme.primary)
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
                Text(String(localized: "加载调用层级中...", table: "LSPSheetsEditor"))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.callHierarchyProvider.rootItem == nil {
            VStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.appLargeTitle)
                    .foregroundColor(theme.textSecondary)
                Text(String(localized: "未找到调用层级信息", table: "LSPSheetsEditor"))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
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
            return theme.info
        case .warning:
            return theme.warning
        case .error:
            return theme.error
        }
    }
}
