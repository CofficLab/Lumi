import AppKit
import LumiUI
import ProviderIdleTime
import SwiftUI

/// Idle Time 设置页：展示推断出的「休息窗口」与活动热度。
///
/// 由旧版 `Plugins/IdleTimePlugin/Sources/Views/IdleTimeSettingsView.swift` 迁移而来，
/// 差异：不再依赖 `KernelLumi`，数据目录由插件注入（来自 StorageProviding）。
@MainActor
public struct IdleTimeSettingsView: View {
    @StateObject private var vm: AppIdleTimeVM
    private let dataDirectory: URL?

    public init(viewModel: AppIdleTimeVM, dataDirectory: URL?) {
        _vm = StateObject(wrappedValue: viewModel)
        self.dataDirectory = dataDirectory
    }

    public init(provider: (any IdleTimeProviding)?, dataDirectory: URL?) {
        _vm = StateObject(wrappedValue: AppIdleTimeVM(provider: provider))
        self.dataDirectory = dataDirectory
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: L("Idle Time"),
            subtitle: L("Track your activity patterns and detect rest windows"),
            showHeader: false
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    IdlePopoverView(snapshot: vm.snapshot)
                }
                .padding(20)
            }
        }
        .frame(minWidth: 520, minHeight: 440)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Spacer()
#if DEBUG
            AppButton(L("Open Data Directory"), systemImage: "folder", size: .small) {
                openDataDirectory()
            }
#endif
        }
        .font(.appCaption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    /// 在 Finder 中打开本插件的磁盘数据目录（活动记录数据库所在位置）。
    private func openDataDirectory() {
        let url = dataDirectory ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}
