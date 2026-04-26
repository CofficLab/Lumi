import MagicKit
import SwiftUI

/// 项目控制视图（整合项目名显示 + 最近项目管理）
/// 默认显示当前项目名，点击后弹出最近项目 Popover
struct ProjectControlView: View {
    @EnvironmentObject var projectVM: ProjectVM

    @State private var isPopoverPresented = false
    @State private var hoverState = false

    var body: some View {
        HStack(spacing: 6) {
            Text(projectVM.currentProjectName.isEmpty ? "Lumi" : projectVM.currentProjectName)
                .font(AppUI.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
                .rotationEffect(.degrees(isPopoverPresented ? 180 : 0))
                .animation(.easeInOut(duration: DesignTokens.Duration.micro), value: isPopoverPresented)
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
            isPopoverPresented = true
        }
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            RecentProjectsSidebarView()
                .frame(width: 300, height: 400)
        }
    }

    // MARK: - Hover State

    private var backgroundColor: Color {
        if isPopoverPresented {
            return Color.accentColor.opacity(0.08)
        } else if hoverState {
            return Color.black.opacity(0.05)
        } else {
            return Color.clear
        }
    }

    private var borderOverlay: some View {
        Group {
            if isPopoverPresented || hoverState {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(Color.accentColor.opacity(isPopoverPresented ? 0.4 : 0.15), lineWidth: 1)
            }
        }
        .animation(.easeOut(duration: DesignTokens.Duration.micro), value: isPopoverPresented)
        .animation(.easeOut(duration: DesignTokens.Duration.micro), value: hoverState)
    }
}

// MARK: - Preview

#Preview("Project Control View") {
    ProjectControlView()
        .inRootView()
}
