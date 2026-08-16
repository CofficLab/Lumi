import KernelCore
import LumiUI
import ProviderDocsView
import ProviderSettingView
import SwiftUI

/// 设置 - 通用 插件
///
/// 在设置视图中注册「通用」入口，详情 UI 与旧版 LumiApp 工具栏右上角
/// 设置按钮 → 设置窗口 → 「通用」标签页（SettingsPlugin.GeneralSettingsView）
/// **完全一致**：`AppSettingsContentScaffold` 包裹的四个分组卡片
/// （新手引导 / Lumi / 网站 / 更新），每行均为 `AppSettingRow`
/// （图标 + 标题 + 描述 + 右侧 `AppButton`）。
///
/// 通过 `SuperPlugin.onBoot(kernel:)` 解析内核中的 `SettingViewProviding`
/// 与 `DocsViewProviding`，用 `addEntries(_:)`（追加语义）注册入口，
/// 不覆盖其他插件贡献的入口。
@MainActor
public final class SettingGeneralPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.setting-general"
    public let order = 100

    /// 版本字符串提供器；默认读取 App bundle 版本，可注入以便测试。
    private let versionProvider: @MainActor () -> String?

    public init(versionProvider: @escaping @MainActor () -> String? = { AppVersion.current }) {
        self.versionProvider = versionProvider
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            // 设置视图未注册：优雅降级，不贡献入口。
            return
        }

        // 捕获 docs provider 引用，供详情视图读取。
        let docsProvider = kernel.resolveProvider((any DocsViewProviding).self)

        let entry = SettingEntryItem(
            id: "general",
            title: "通用",
            systemImage: "gearshape",
            order: 100
        ) { [versionProvider, docsProvider] in
            GeneralSettingsDetailView(
                version: versionProvider(),
                docsProvider: docsProvider
            )
        }

        settings.addEntries([entry])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["general"])
    }
}

// MARK: - 通用设置详情视图

/// 通用设置详情视图 —— 复刻旧版 LumiApp（SettingsPlugin.GeneralSettingsView）
/// 设置窗口「通用」标签页：四个分组卡片，逐行、逐文案一致。
private struct GeneralSettingsDetailView: View {
    let version: String?
    let docsProvider: (any DocsViewProviding)?

    /// 是否展示说明书浏览器。
    @State private var isPresentingManuals = false

    /// App bundle 元数据（名称 / 包名 / 版本 / 构建）。
    private let bundleInfo = AppBundleInfo()

    /// 所有提供了说明书的文档条目（来自 `DocsViewProviding`）。
    private var manuals: [DocsEntry] {
        docsProvider?.manualEntries ?? []
    }

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                onboardingSection
                lumiSection
                websiteSection
                updatesSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $isPresentingManuals) {
            if !manuals.isEmpty {
                ManualsBrowserView(manuals: manuals)
            }
        }
    }

    // MARK: - 新手引导

    private var onboardingSection: some View {
        AppSettingSection(
            title: "新手引导",
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: "重新查看新手引导",
                    description: "重放首次启动引导流程。",
                    icon: "graduationcap"
                ) {
                    AppButton(
                        "开始",
                        systemImage: "arrow.right",
                        style: .secondary,
                        size: .small
                    ) {
                        // 与旧版一致：广播重放引导请求，由宿主监听并展示。
                        NotificationCenter.default.post(
                            name: .lumiShowOnboarding,
                            object: nil,
                            userInfo: [LumiOnboardingNotification.resetKey: true]
                        )
                    }
                }

                if !manuals.isEmpty {
                    Divider()
                        .padding(.vertical, 8)

                    AppSettingRow(
                        title: "说明书",
                        description: "各功能的使用指南。",
                        icon: "book"
                    ) {
                        AppButton(
                            "打开",
                            systemImage: "book.pages",
                            style: .secondary,
                            size: .small
                        ) {
                            isPresentingManuals = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Lumi（应用信息）

    private var lumiSection: some View {
        AppSettingSection(
            title: "Lumi",
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: "Name",
                    description: bundleInfo.name,
                    icon: "app"
                ) {
                    EmptyView()
                }
                Divider()
                    .padding(.vertical, 8)
                AppSettingRow(
                    title: "Bundle ID",
                    description: bundleInfo.bundleIdentifier,
                    icon: "number"
                ) {
                    EmptyView()
                }
                Divider()
                    .padding(.vertical, 8)
                AppSettingRow(
                    title: "Version",
                    description: bundleInfo.version ?? "Not Set",
                    icon: "info.circle"
                ) {
                    EmptyView()
                }
                Divider()
                    .padding(.vertical, 8)
                AppSettingRow(
                    title: "Build",
                    description: bundleInfo.build ?? "Not Set",
                    icon: "hammer"
                ) {
                    EmptyView()
                }
            }
        }
    }

    // MARK: - 网站

    private var websiteSection: some View {
        AppSettingSection(
            title: "网站",
            titleAlignment: .leading
        ) {
            AppSettingRow(
                title: "官方网站",
                description: "coffic.cn/lumi",
                icon: "globe"
            ) {
                AppButton(
                    "访问",
                    systemImage: "arrow.up.forward.square",
                    style: .secondary,
                    size: .small
                ) {
                    if let url = URL(string: "https://coffic.cn/lumi") {
                        #if canImport(AppKit)
                        NSWorkspace.shared.open(url)
                        #elseif canImport(UIKit)
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
            }
        }
    }

    // MARK: - 更新

    /// 与旧版一致：`allowsAppUpdates` 的宿主（Lumi 直营）展示「检查更新」行，
    /// 点击广播 `checkForUpdates` 通知，由宿主（如 Sparkle 更新插件）消费。
    private var updatesSection: some View {
        AppSettingSection(
            title: "Updates",
            titleAlignment: .leading
        ) {
            AppSettingRow(
                title: "Check for Updates",
                description: "Check whether a newer version of Lumi is available.",
                icon: "arrow.down.circle"
            ) {
                AppButton(
                    "Check...",
                    systemImage: "arrow.triangle.2.circlepath",
                    style: .secondary,
                    size: .small
                ) {
                    NotificationCenter.default.post(
                        name: Notification.Name("checkForUpdates"),
                        object: nil
                    )
                }
            }
        }
    }
}

// MARK: - Onboarding 通知

/// 与旧版 KernelLumi.KernelEvents 一致的通知名与重置 key。
private enum LumiOnboardingNotification {
    /// 重放新手引导时置 true，宿主据此强制重置引导进度。
    static let resetKey = "reset"
}

private extension Notification.Name {
    /// 请求展示/重放新手引导（`Onboarding.Show`）。
    static let lumiShowOnboarding = Notification.Name("Onboarding.Show")
}

// MARK: - 说明书浏览器

/// 说明书浏览器 —— 主从式布局：左侧为提供了说明书的插件名列表，
/// 右侧为选中插件的说明书内容。
///
/// 复刻自旧版 Lumi SettingsPlugin 的 ManualsBrowserView（布局、尺寸、
/// 选中态、关闭按钮逐项一致）。
private struct ManualsBrowserView: View {
    let manuals: [DocsEntry]

    @State private var selectedID: String?

    @Environment(\.dismiss) private var dismiss

    private var selectedManual: DocsEntry? {
        manuals.first { $0.id == selectedID } ?? manuals.first
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(minWidth: 860, minHeight: 560)
        .onAppear {
            if selectedID == nil {
                selectedID = manuals.first?.id
            }
        }
    }

    // MARK: - 左侧插件列表

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "book")
                    .foregroundStyle(.secondary)
                Text("说明书")
                    .font(.headline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(manuals) { manual in
                        sidebarRow(manual)
                    }
                }
                .padding(10)
            }
        }
        .frame(width: 220)
        .background(Color.primary.opacity(0.03))
    }

    private func sidebarRow(_ manual: DocsEntry) -> some View {
        let isSelected = manual.id == selectedManual?.id
        return Button {
            selectedID = manual.id
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "book")
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                Text(manual.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 右侧说明书内容

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let manual = selectedManual {
                HStack(spacing: 10) {
                    Text(manual.name)
                        .font(.headline)
                    Spacer()
                    AppIconButton(systemImage: "xmark") {
                        dismiss()
                    }
                }
                .padding(16)

                Divider()

                ScrollView {
                    manual.makeView()
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "book")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("暂时还没有说明书。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
