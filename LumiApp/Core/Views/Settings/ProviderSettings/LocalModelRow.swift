import SwiftUI

/// 本地模型行：显示名称、大小、已缓存、下载进度/加载按钮
struct LocalModelRow: View {
    let model: LocalModelInfo
    let isCached: Bool
    let isSelected: Bool
    let isDownloading: Bool
    let downloadStatus: LocalDownloadStatus?
    let isDownloadDisabled: Bool
    /// 当前行模型是否已加载到内存
    let isThisModelLoaded: Bool
    /// 是否有任意模型已加载（用于禁用「卸载」当无模型加载时）
    let hasAnyModelLoaded: Bool
    /// 当前行模型是否正在加载到内存
    let isLoading: Bool
    /// 是否禁用加载按钮（例如正在加载其他模型时）
    let isLoadDisabled: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onLoad: () -> Void
    let onUnload: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // 状态图标
            Group {
                if isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else if isCached {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(DesignTokens.Color.semantic.primary.opacity(0.8))
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(DesignTokens.Color.semantic.textSecondary)
                }
            }
            .frame(width: 20, height: 20)
            .animation(.easeInOut(duration: 0.22), value: isLoading)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                // 体积、内存要求、下载状态
                HStack(spacing: 6) {
                    Text("体积 \(model.size)")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text("·")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text("电脑内存 ≥ \(model.minRAM) GB")
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    if isDownloading, case .downloading(let fraction) = downloadStatus {
                        Text("· \(Int(fraction * 100))%")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.primary)
                            .monospacedDigit()
                    } else if isCached {
                        if isLoading {
                            Text("· 加载中…")
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(DesignTokens.Color.semantic.primary)
                        } else {
                            Text("· 已缓存")
                                .font(DesignTokens.Typography.caption2)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                    }
                }
                if !model.description.isEmpty {
                    Text(model.description)
                        .font(DesignTokens.Typography.caption2)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        .lineLimit(2)
                }
                // 功能特性：工具调用、视觉等，便于用户理解模型能力
                if model.supportsTools || model.supportsVision {
                    HStack(spacing: 6) {
                        Text("功能特性：")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        if model.supportsTools {
                            capabilityTag("工具调用", systemImage: "wrench.and.screwdriver")
                        }
                        if model.supportsVision {
                            capabilityTag("视觉", systemImage: "eye")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(accessibilityRowLabel)
            .accessibilityHint("本地模型")

            if isDownloading {
                ProgressView(value: downloadProgressFraction)
                    .frame(width: 60)
            } else if !isCached {
                Button("下载", action: onDownload)
                    .font(DesignTokens.Typography.caption1)
                    .disabled(isDownloadDisabled)
                    .accessibilityLabel("下载")
                    .accessibilityHint("下载此模型到本地")
            } else {
                if isThisModelLoaded {
                    Text("已加载")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                } else if isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("加载中…")
                            .font(DesignTokens.Typography.caption1)
                            .foregroundColor(DesignTokens.Color.semantic.primary)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    Button("加载", action: onLoad)
                        .font(DesignTokens.Typography.caption1)
                        .disabled(isLoadDisabled)
                        .accessibilityLabel("加载")
                        .accessibilityHint("将模型加载到内存以进行推理")
                }
                Button("卸载", action: onUnload)
                    .font(DesignTokens.Typography.caption1)
                    .disabled(!hasAnyModelLoaded)
                    .accessibilityLabel("卸载")
                    .accessibilityHint("从内存卸载当前已加载的模型")
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isLoading)
        .padding(DesignTokens.Spacing.sm)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(rowBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .stroke(Color.white.opacity(isHovered ? 0.15 : 0), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    private var downloadProgressFraction: Double {
        guard case .downloading(let fraction) = downloadStatus else { return 0 }
        return fraction
    }

    private var accessibilityRowLabel: String {
        var parts = [model.displayName]
        if isDownloading {
            parts.append("下载中")
        } else if isLoading {
            parts.append("加载中")
        } else if isThisModelLoaded {
            parts.append("已加载")
        } else if isCached {
            parts.append("已缓存")
        } else {
            parts.append("未下载")
        }
        parts.append("体积 \(model.size)，需要内存至少 \(model.minRAM) GB")
        return parts.joined(separator: "，")
    }

    private var rowBackgroundColor: Color {
        if isLoading {
            return DesignTokens.Color.semantic.primary.opacity(0.06)
        }
        if isSelected {
            return DesignTokens.Color.semantic.primary.opacity(0.08)
        }
        if isHovered {
            return Color.blue.opacity(0.1)
        }
        return Color.white.opacity(0.5)
    }

    private func capabilityTag(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(DesignTokens.Typography.caption2)
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.15))
            )
    }
}
