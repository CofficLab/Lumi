import SwiftUI

/// 头部左侧视图：应用图标、当前项目名（支持下拉选择）
struct ChatHeaderLeadingView: View {
    @EnvironmentObject var projectVM: WindowProjectVM

    @State private var isDropdownPresented = false
    @State private var hoverState = false

    var body: some View {
        HStack(spacing: 12) {
            Text(projectVM.currentProjectName.isEmpty ? "Lumi" : projectVM.currentProjectName)
                .font(.system(size: 15, weight: .regular))
                .fontWeight(.medium)
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(hex: "98989E"))
                .rotationEffect(.degrees(isDropdownPresented ? 180 : 0))
                .animation(.easeInOut(duration: 0.15), value: isDropdownPresented)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(isDropdownPresented ? 0.4 : 0.15), lineWidth: 1)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isDropdownPresented)
        .animation(.easeOut(duration: 0.15), value: hoverState)
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
        withAnimation(.easeInOut(duration: 0.20)) {
            isDropdownPresented.toggle()
        }
    }

    private func selectProject(_ project: Project) {
        Task { @MainActor in
            projectVM.switchProject(to: project)
        }
        withAnimation(.easeInOut(duration: 0.20)) {
            isDropdownPresented = false
        }
    }
}

// MARK: - Preview

#Preview("Chat Header Leading") {
    ChatHeaderLeadingView()
        .inRootView()
}
