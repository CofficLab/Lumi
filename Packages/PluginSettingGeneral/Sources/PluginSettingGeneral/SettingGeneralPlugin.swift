import KernelCore
import ProviderDocsView
import ProviderSettingView
import SwiftUI

/// 设置 - 通用 插件
///
/// 在设置视图中注册「通用」入口，详情展示当前 App 版本，以及各插件贡献的
/// 「关于」与「说明书」文档（来自 `DocsViewProviding`）。
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

/// 通用设置详情视图：App 版本 + 文档（关于 / 说明书）。
private struct GeneralSettingsDetailView: View {
    let version: String?
    let docsProvider: (any DocsViewProviding)?

    /// 是否展示说明书浏览器。
    @State private var isPresentingManuals = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("通用")
                .font(.title2)

            GroupBox("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(version ?? "未知")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // 文档：关于
            if let about = docsProvider?.aboutEntries.first {
                GroupBox("关于本应用") {
                    Button {
                        // 打开关于页（sheet 展示选中插件的 About）
                    } label: {
                        HStack {
                            Text(about.name)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // 文档：说明书浏览器入口
            if let manuals = docsProvider?.manualEntries, !manuals.isEmpty {
                GroupBox("说明书") {
                    Button {
                        isPresentingManuals = true
                    } label: {
                        HStack {
                            Text("用户说明书")
                            Spacer()
                            Text("\(manuals.count) 本")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $isPresentingManuals) {
            if let manuals = docsProvider?.manualEntries {
                ManualsBrowserView(manuals: manuals)
            }
        }
    }
}

/// 说明书浏览器 —— 主从式布局：左侧为提供了说明书的插件名列表，
/// 右侧为选中插件的说明书内容。
///
/// 复刻自 Lumi SettingsPlugin 的 ManualsBrowserView。
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
        .frame(minWidth: 720, minHeight: 480)
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
                Text("用户说明书")
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
        .frame(width: 200)
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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
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
                    Text("暂无说明书")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
