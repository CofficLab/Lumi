import MagicKit
import SwiftUI

/// 头部左侧视图：应用图标、当前项目名（支持下拉选择）
struct ChatHeaderLeadingView: View {
    @EnvironmentObject var projectVM: ProjectVM

    @State private var isDropdownPresented = false
    @State private var hoverState = false

    var body: some View {
        HStack(spacing: 12) {
            Text(projectVM.currentProjectName.isEmpty ? "Lumi" : projectVM.currentProjectName)
                .font(AppUI.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
                .rotationEffect(.degrees(isDropdownPresented ? 180 : 0))
                .animation(.easeInOut(duration: DesignTokens.Duration.micro), value: isDropdownPresented)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        .overlay(borderOverlay)
        .onHover { hovering in
            hoverState = hovering
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleDropdown()
        }
        .overlay(alignment: .topLeading) {
            dropdownContent
        }
        .onOpenProjectSelector {
            isDropdownPresented = true
        }
    }

    // MARK: - Hover State

    private var backgroundColor: Color {
        if isDropdownPresented {
            return Color.accentColor.opacity(0.08)
        } else if hoverState {
            return Color.black.opacity(0.05)
        } else {
            return Color.clear
        }
    }

    private var borderOverlay: some View {
        Group {
            if isDropdownPresented || hoverState {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(Color.accentColor.opacity(isDropdownPresented ? 0.4 : 0.15), lineWidth: 1)
            }
        }
        .animation(.easeOut(duration: DesignTokens.Duration.micro), value: isDropdownPresented)
        .animation(.easeOut(duration: DesignTokens.Duration.micro), value: hoverState)
    }

    // MARK: - Dropdown

    private var dropdownContent: some View {
        Group {
            if isDropdownPresented {
                ProjectDropdownMenu(
                    isPresented: $isDropdownPresented,
                    onSelect: { project in
                        selectProject(project)
                    }
                )
                .offset(y: 32) // 下拉菜单偏移到按钮下方
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
    }

    // MARK: - Action

    private func toggleDropdown() {
        withAnimation(.easeInOut(duration: DesignTokens.Duration.standard)) {
            isDropdownPresented.toggle()
        }
    }

    private func selectProject(_ project: Project) {
        Task { @MainActor in
            projectVM.switchProject(to: project)
        }
        withAnimation(.easeInOut(duration: DesignTokens.Duration.standard)) {
            isDropdownPresented = false
        }
    }
}

// MARK: - Preview

#Preview("Chat Header Leading") {
    ChatHeaderLeadingView()
        .inRootView()
}
