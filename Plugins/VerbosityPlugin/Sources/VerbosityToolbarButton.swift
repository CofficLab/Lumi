import LumiCoreKit
import LumiUI
import SwiftUI

/// 详细程度切换工具栏按钮。
///
/// 这里的详细程度只控制消息列表 UI 的渲染密度，不改变发送给模型的请求。
public struct VerbosityToolbarButton: View {
    @EnvironmentObject private var llmVM: AppLLMVM
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @State private var isPopoverPresented = false

    public init() {}

    public var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: llmVM.verbosity.iconName)
                    .font(.system(size: 13))
                Text(llmVM.verbosity.levelCode)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(llmVM.verbosity.description)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            VerbosityLevelPopover(
                selectedLevel: llmVM.verbosity,
                onSelect: selectLevel
            )
        }
        .onAppear(perform: restoreConversationPreference)
        .onChange(of: conversationVM.selectedConversationId) { _, _ in
            restoreConversationPreference()
        }
    }

    private func selectLevel(_ level: ResponseVerbosity) {
        withAnimation {
            llmVM.setVerbosity(level)
        }
        conversationVM.saveVerbosityPreference(level)
        isPopoverPresented = false
    }

    private func restoreConversationPreference() {
        if let preference = conversationVM.getVerbosityPreference() {
            llmVM.setVerbosity(preference)
        } else {
            llmVM.setVerbosity(.brief)
        }
    }

    private var foregroundColor: Color {
        switch llmVM.verbosity {
        case .brief:
            return .blue
        case .standard:
            return theme.textSecondary
        case .detailed:
            return .purple
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }
}

private struct VerbosityLevelPopover: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let selectedLevel: ResponseVerbosity
    let onSelect: (ResponseVerbosity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("详细级别")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            ForEach(ResponseVerbosity.allCases) { level in
                Button {
                    onSelect(level)
                } label: {
                    VerbosityLevelRow(
                        level: level,
                        isSelected: level == selectedLevel
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 260)
    }
}

private struct VerbosityLevelRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let level: ResponseVerbosity
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: level.iconName)
                .font(.system(size: 13))
                .frame(width: 18)
                .foregroundColor(isSelected ? theme.primary : theme.textSecondary)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(level.levelCode)
                        .font(.system(size: 12, weight: .semibold))
                    Text(level.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(level.description)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.primary)
            }
        }
        .foregroundColor(theme.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? theme.primary.opacity(0.12) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
