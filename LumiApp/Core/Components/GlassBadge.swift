//
//  GlassBadge.swift
//  Lumi
//
//  Created by Design System on 2025-02-11.
//  玻璃标签组件
//

import SwiftUI

// MARK: - 玻璃标签
///
/// 玻璃态标签，用于状态标识。
///
struct GlassBadge: View {
    enum Style {
        case neutral
        case success
        case warning
        case error
        case info
        case glow(SwiftUI.Color)
    }

    let text: LocalizedStringKey
    let style: Style

    var body: some View {
        Text(text)
            .font(DesignTokens.Typography.caption1)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(background)
            .overlay(border)
            .cornerRadius(DesignTokens.Radius.full)
    }

    private var foregroundColor: SwiftUI.Color {
        switch style {
        case .neutral:
            return DesignTokens.Color.semantic.textSecondary
        case .success:
            return DesignTokens.Color.semantic.success
        case .warning:
            return DesignTokens.Color.semantic.warning
        case .error:
            return DesignTokens.Color.semantic.error
        case .info:
            return DesignTokens.Color.semantic.info
        case .glow(let color):
            return color
        }
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .neutral:
            RoundedRectangle(cornerRadius: DesignTokens.Radius.full)
                .fill(DesignTokens.Material.glass.opacity(0.15))
        case .success:
            DesignTokens.Color.semantic.success.opacity(0.15)
        case .warning:
            DesignTokens.Color.semantic.warning.opacity(0.15)
        case .error:
            DesignTokens.Color.semantic.error.opacity(0.15)
        case .info:
            DesignTokens.Color.semantic.info.opacity(0.15)
        case .glow(let color):
            color.opacity(0.2)
        }
    }

    @ViewBuilder private var border: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.full)
            .stroke(borderColor.opacity(0.2), lineWidth: 1)
    }

    private var borderColor: SwiftUI.Color {
        switch style {
        case .neutral:
            return SwiftUI.Color.white
        case .success:
            return DesignTokens.Color.semantic.success
        case .warning:
            return DesignTokens.Color.semantic.warning
        case .error:
            return DesignTokens.Color.semantic.error
        case .info:
            return DesignTokens.Color.semantic.info
        case .glow(let color):
            return color
        }
    }
}

// MARK: - 预览
#Preview("玻璃标签") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        HStack(spacing: DesignTokens.Spacing.sm) {
            GlassBadge(text: "中性", style: .neutral)
            GlassBadge(text: "成功", style: .success)
            GlassBadge(text: "警告", style: .warning)
            GlassBadge(text: "错误", style: .error)
            GlassBadge(text: "信息", style: .info)
        }

        HStack(spacing: DesignTokens.Spacing.sm) {
            GlassBadge(text: "紫色", style: .glow(.purple))
            GlassBadge(text: "蓝色", style: .glow(.blue))
            GlassBadge(text: "绿色", style: .glow(.green))
            GlassBadge(text: "橙色", style: .glow(.orange))
        }
    }
    .padding(DesignTokens.Spacing.lg)
    .frame(maxWidth: .infinity)
    .background(DesignTokens.Color.basePalette.deepBackground)
}
