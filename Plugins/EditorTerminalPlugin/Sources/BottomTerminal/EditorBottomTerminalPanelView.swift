import LumiKernel
import LumiUI
import SwiftUI
import TerminalCoreKit

@MainActor
public enum EditorBottomTerminalBridge {
    nonisolated(unsafe) static var kernel: LumiKernel?
    public static var editorThemeIdProvider: (() -> String)?

    public static var currentProjectPath: String? {
        kernel?.project?.currentProject?.path
    }
}

/// Terminal panel content for the editor bottom area.
public struct EditorBottomTerminalPanelView: View {
    @LumiTheme private var theme: any LumiUITheme
    @ObservedObject private var viewModel = TerminalTabsViewModel.editorBottomShared

    public init() {}

    private var workingDirectory: String? {
        EditorBottomTerminalBridge.currentProjectPath
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabBar

            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                terminalContent
            }
        }
        .background(theme.background)
        .onAppear {
            viewModel.ensureInitialSession(workingDirectory: workingDirectory)
        }
        .onChange(of: workingDirectory) { _, newValue in
            viewModel.updateDefaultWorkingDirectory(newValue)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(viewModel.sessions.enumerated()), id: \.element.id) { index, session in
                BottomTerminalTabItem(
                    title: session.title,
                    isSelected: viewModel.selectedSessionId == session.id,
                    onSelect: { viewModel.selectSession(session.id) },
                    onClose: { viewModel.closeSession(session.id) }
                )

                if index < viewModel.sessions.count - 1 {
                    Rectangle()
                        .fill(theme.divider.opacity(0.7))
                        .frame(width: 1, height: 14)
                        .padding(.horizontal, 2)
                }
            }

            Button {
                viewModel.createSession(workingDirectory: workingDirectory)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surface.opacity(0.7))
    }

    private var terminalContent: some View {
        ZStack {
            ForEach(viewModel.sessions) { session in
                TerminalSessionContainerView(session: session)
                    .opacity(viewModel.selectedSessionId == session.id ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(theme.textTertiary)
            Text(LumiPluginLocalization.string("No open terminals", bundle: .module))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textSecondary)
            Button(LumiPluginLocalization.string("New Terminal", bundle: .module)) {
                viewModel.createSession(workingDirectory: workingDirectory)
            }
            .font(.appMicroEmphasized)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}

private extension TerminalTabsViewModel {
    static let editorBottomShared = TerminalTabsViewModel(
        themeIdProvider: { EditorBottomTerminalBridge.editorThemeIdProvider?() ?? "xcode-dark" }
    )
}

private struct BottomTerminalTabItem: View {
    @LumiTheme private var theme: any LumiUITheme

    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onSelect) {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.system(size: 9, weight: .semibold))
                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? theme.textPrimary.opacity(0.08) : Color.clear)
                )
            }
            .buttonStyle(.plain)

            if isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }
        }
    }
}