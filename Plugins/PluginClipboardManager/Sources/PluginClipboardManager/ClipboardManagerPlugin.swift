import os
import SwiftUI
import LumiUI
import LumiCoreKit

public actor ClipboardManagerPlugin: SuperPlugin {
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.clipboard-manager")

    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true
    public static let id = "ClipboardManager"
    public static let navigationId = "clipboard_manager"
    public static let displayName = String(localized: "Clipboard", table: "ClipboardManager")
    public static let description = String(localized: "Manage clipboard history and snippets", table: "ClipboardManager")
    public static let iconName = "doc.on.clipboard"
    public static var category: PluginCategory { .general }
    public static var order: Int { 70 }
    public static let policy: PluginPolicy = .alwaysOn

    public static let shared = ClipboardManagerPlugin()
    private nonisolated static let settingsStore = ClipboardManagerPluginLocalStore.shared
    private nonisolated static let monitoringKey = "ClipboardMonitoringEnabled"

    // MARK: - Lifecycle

    public nonisolated func onRegister() {
        // Initialize defaults
        Self.settingsStore.migrateLegacyValueIfMissing(forKey: Self.monitoringKey)
        if Self.settingsStore.object(forKey: Self.monitoringKey) == nil {
            Self.settingsStore.set(true, forKey: Self.monitoringKey)
        }
    }

    public nonisolated func onEnable() {
        Task { @MainActor in
            if Self.settingsStore.bool(forKey: Self.monitoringKey) {
                ClipboardMonitor.shared.startMonitoring()
            }
        }
    }

    public nonisolated func onDisable() {
        Task { @MainActor in
            ClipboardMonitor.shared.stopMonitoring()
        }
    }

    // MARK: - UI

    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(ClipboardHistoryView())
        }
    }

    @MainActor
    public func addPosterViews() -> [AnyView] {
        [
            AnyView(ClipboardManagerPosterView()),
            AnyView(ClipboardManagerPinnedPosterView())
        ]
    }
}

private struct ClipboardManagerPosterView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public var body: some View {
        ZStack {
            theme.appWindowBackground

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.appTitle)
                        .foregroundColor(theme.primary)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(theme.appAccentSoftFill)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("剪贴板历史")
                            .font(.appBodyEmphasized)
                            .foregroundColor(theme.textPrimary)

                        Text("最近复制的文本、链接和片段")
                            .font(.appMicro)
                            .foregroundColor(theme.textSecondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "pin.fill")
                        .font(.appCaption)
                        .foregroundColor(theme.primary)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(theme.appAccentSoftFill))
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.appCaption)
                        .foregroundColor(theme.textTertiary)

                    Text("搜索剪贴板")
                        .font(.appCaption)
                        .foregroundColor(theme.textTertiary)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.appPanelBackground)
                )

                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 8) {
                        clipboardRow(
                            title: "复制的代码片段",
                            detail: "func buildPosterView()",
                            symbol: "curlybraces"
                        )
                        clipboardRow(
                            title: "产品页面链接",
                            detail: "https://example.com/release",
                            symbol: "link"
                        )
                        clipboardRow(
                            title: "会议记录摘要",
                            detail: "插件设置页交互优化",
                            symbol: "text.alignleft"
                        )
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("固定片段")
                            .font(.appCaptionEmphasized)
                            .foregroundColor(theme.textPrimary)

                        pinnedSnippet("邮件签名")
                        pinnedSnippet("发布说明")
                        pinnedSnippet("常用提示词")
                    }
                    .frame(width: 128, alignment: .topLeading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(theme.appPanelBackground)
                    )
                }
            }
            .padding(16)
        }
    }

    private func clipboardRow(title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.appCaption)
                .foregroundColor(theme.primary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(theme.appAccentSoftFill))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                Text(detail)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.elevatedSurface)
        )
    }

    private func pinnedSnippet(_ title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "pin")
                .font(.appMicro)
                .foregroundColor(theme.primary)

            Text(title)
                .font(.appMicroEmphasized)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(theme.appStatusMutedFill)
        )
    }
}

private struct ClipboardManagerPinnedPosterView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public var body: some View {
        ZStack {
            theme.appWindowBackground

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("固定常用片段", systemImage: "pin.fill")
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)

                    Text("把签名、回复模板和常用命令保存在剪贴板里，随时调用。")
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(3)

                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        snippetTag("签名")
                        snippetTag("模板")
                        snippetTag("命令")
                    }
                }
                .frame(width: 180, alignment: .leading)

                VStack(spacing: 10) {
                    pinnedCard(title: "客户回复模板", detail: "您好，已收到您的反馈...")
                    pinnedCard(title: "Git 提交命令", detail: "git commit -m \"update\"")
                    pinnedCard(title: "应用签名", detail: "Lumi Team")
                }
                .frame(maxWidth: .infinity)
            }
            .padding(18)
        }
    }

    private func snippetTag(_ title: String) -> some View {
        Text(title)
            .font(.appMicroEmphasized)
            .foregroundColor(theme.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(theme.appAccentSoftFill))
    }

    private func pinnedCard(title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "pin")
                .font(.appCaption)
                .foregroundColor(theme.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(theme.appAccentSoftFill))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                Text(detail)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.elevatedSurface)
        )
    }
}
