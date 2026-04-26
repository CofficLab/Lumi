import SwiftUI

// MARK: - Installed Extensions View

struct InstalledExtensionsView: View {
    @StateObject private var manager = CodeServerManager.shared

    var body: some View {
        if manager.isLoadingExtensions {
            VStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("加载扩展列表...")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
        } else if manager.installedExtensions.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 24))
                    .foregroundColor(DesignTokens.Color.semantic.textDisabled)

                Text("未安装任何扩展")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                Text("点击上方「市场」标签搜索安装扩展")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(manager.installedExtensions) { ext in
                        ExtensionRowView(ext: ext)
                            .padding(.vertical, 6)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Extension Row View

/// 单个扩展行视图
struct ExtensionRowView: View {
    let ext: CodeServerExtension
    @StateObject private var manager = CodeServerManager.shared
    @State private var isUninstalling = false

    /// 是否为图标主题扩展
    private var isIconTheme: Bool {
        let lowercasedId = ext.id.lowercased()
        return lowercasedId.contains("icon-theme") || lowercasedId.contains("icons")
    }

    var body: some View {
        HStack(spacing: 8) {
            // 图标 + 名称
            VStack(alignment: .leading, spacing: 2) {
                Text(ext.id)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    .lineLimit(1)

                if let version = ext.version {
                    Text("v\(version)")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }
            }

            Spacer()

            // 图标主题扩展显示「应用」按钮
            if isIconTheme {
                Button(action: {
                    manager.applyIconTheme(ext.id)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10))
                        Text("应用")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .help("应用此图标主题")
            }

            // 卸载按钮
            Button(action: {
                uninstall()
            }) {
                if isUninstalling {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            .help("卸载扩展")
            .disabled(isUninstalling)
        }
        .padding(.horizontal, 4)
    }

    private func uninstall() {
        isUninstalling = true

        Task {
            _ = await manager.uninstallExtension(ext.id)
            await MainActor.run {
                isUninstalling = false
            }
        }
    }
}
