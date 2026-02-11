import SwiftUI
import AppKit

struct TextActionsSettingsView: View {
    @StateObject private var manager = TextSelectionManager.shared
    @AppStorage("TextActionsEnabled") private var isEnabled = false
    
    var body: some View {
        HStack(spacing: 0) {
            TextActionPreviewView(isEnabled: isEnabled)

            GlassDivider()
                .frame(width: 1, height: 360)
                .rotationEffect(.degrees(90))

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    MystiqueGlassCard {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("General Settings")
                                .font(DesignTokens.Typography.title3)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                            Toggle("Enable Text Selection Menu", isOn: $isEnabled)
                                .onChange(of: isEnabled) { _, newValue in
                                    if newValue {
                                        manager.startMonitoring()
                                        _ = TextActionMenuController.shared
                                    } else {
                                        manager.stopMonitoring()
                                    }
                                }

                            if !manager.isPermissionGranted {
                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(DesignTokens.Color.semantic.warning)
                                    Text("Accessibility permission is required to detect text selection")
                                        .font(DesignTokens.Typography.caption1)
                                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                    GlassButton(title: "Open System Settings", style: .secondary) {
                                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                                        NSWorkspace.shared.open(url)
                                    }
                                    .frame(maxWidth: 180)
                                }
                                .padding(.top, DesignTokens.Spacing.xs)
                            }
                        }
                    }

                    MystiqueGlassCard {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Supported Actions")
                                .font(DesignTokens.Typography.title3)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                            VStack(spacing: DesignTokens.Spacing.xs) {
                                ForEach(TextActionType.allCases) { action in
                                    GlassRow {
                                        HStack {
                                            Image(systemName: action.icon)
                                                .frame(width: 20)
                                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                            Text(action.title)
                                                .font(DesignTokens.Typography.body)
                                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                            Spacer()
                                            Image(systemName: "checkmark")
                                                .foregroundColor(DesignTokens.Color.semantic.primary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
        }
        .onAppear {
            manager.checkPermission()
            if isEnabled {
                manager.startMonitoring()
                _ = TextActionMenuController.shared
            }
        }
    }
}

struct TextActionPreviewView: View {
    let isEnabled: Bool
    
    var body: some View {
        ZStack {
            DesignTokens.Color.basePalette.surfaceBackground
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Preview")
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                
                ZStack {
                    // Document background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignTokens.Material.glass)
                        .frame(width: 220, height: 160)
                    
                    // Mock content
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.2))
                            .frame(width: 180, height: 8)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.2))
                            .frame(width: 160, height: 8)
                        
                        HStack(spacing: 0) {
                            Text("Select ")
                                .font(.system(size: 12))
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            
                            Text("this text")
                                .font(.system(size: 12))
                                .padding(.horizontal, 2)
                                .background(isEnabled ? DesignTokens.Color.semantic.primary.opacity(0.3) : SwiftUI.Color.clear)
                                .foregroundColor(isEnabled ? DesignTokens.Color.semantic.primary : DesignTokens.Color.semantic.textSecondary)
                                .overlay(
                                    GeometryReader { geo in
                                        if isEnabled {
                                            MockActionMenu()
                                                .offset(x: -20, y: -60)
                                        }
                                    }
                                )
                            
                            Text(" to see.")
                                .font(.system(size: 12))
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DesignTokens.Color.semantic.textTertiary.opacity(0.2))
                            .frame(width: 140, height: 8)
                    }
                }
            }
            .padding()
        }
        .frame(width: 260)
    }
}

struct MockActionMenu: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(TextActionType.allCases) { action in
                VStack(spacing: 4) {
                    Image(systemName: action.icon)
                        .font(.system(size: 14))
                    Text(action.title)
                        .font(.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                }
                .frame(width: 44, height: 44)
                .background(DesignTokens.Material.glass)
                .cornerRadius(DesignTokens.Radius.sm)
            }
        }
        .padding(DesignTokens.Spacing.xs)
        .background(DesignTokens.Material.glass)
        .cornerRadius(DesignTokens.Radius.md)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .withNavigation(TextActionsPlugin.id)
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
