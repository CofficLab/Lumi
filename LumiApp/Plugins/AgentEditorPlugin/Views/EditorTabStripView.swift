import SwiftUI
import MagicKit

struct EditorTabStripView: View {
    let tabs: [EditorTab]
    let activeSessionID: EditorSession.ID?
    let canNavigateBack: Bool
    let canNavigateForward: Bool
    let onNavigateBack: () -> Void
    let onNavigateForward: () -> Void
    let onSelect: (EditorTab) -> Void
    let onClose: (EditorTab) -> Void
    let onCloseOthers: (EditorTab) -> Void
    let onTogglePinned: (EditorTab) -> Void

    var body: some View {
        HStack(spacing: 4) {
            navigationButton(
                systemName: "chevron.left",
                isEnabled: canNavigateBack,
                action: onNavigateBack
            )

            navigationButton(
                systemName: "chevron.right",
                isEnabled: canNavigateForward,
                action: onNavigateForward
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        tabItem(for: tab)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
        }
        .background(AppUI.Color.semantic.textTertiary.opacity(0.04))
    }

    private func tabItem(for tab: EditorTab) -> some View {
        let isActive = tab.sessionID == activeSessionID

        return HStack(spacing: 6) {
            Circle()
                .fill(tab.isDirty ? AppUI.Color.semantic.warning : AppUI.Color.semantic.textTertiary.opacity(0.35))
                .frame(width: 6, height: 6)

            if tab.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }

            Text(tab.title)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textSecondary)
                .lineLimit(1)

            Button {
                onClose(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(isActive ? 1 : 0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isActive ? AppUI.Color.semantic.textPrimary.opacity(0.07) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isActive ? AppUI.Color.semantic.textPrimary.opacity(0.08) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(tab)
        }
        .contextMenu {
            Button(
                tab.isPinned
                    ? String(localized: "Unpin Tab", table: "LumiEditor")
                    : String(localized: "Pin Tab", table: "LumiEditor")
            ) {
                onTogglePinned(tab)
            }
            Button(String(localized: "Close Others", table: "LumiEditor")) {
                onCloseOthers(tab)
            }
        }
    }

    private func navigationButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isEnabled ? AppUI.Color.semantic.textSecondary : AppUI.Color.semantic.textTertiary.opacity(0.5))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isEnabled ? AppUI.Color.semantic.textPrimary.opacity(0.05) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .padding(.leading, systemName == "chevron.left" ? 8 : 0)
    }
}
