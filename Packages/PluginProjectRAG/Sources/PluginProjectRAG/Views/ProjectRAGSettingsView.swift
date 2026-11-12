import LumiUI
import ProjectRAGEngine
import SwiftUI

/// Project RAG 全局设置：自动注入开关与后台索引暂停。
///
/// 两个开关都是进程级语义（注入 Hook 全局读取、索引暂停作用于整个
/// RAGService），因此放在独立设置入口而不是按项目展示的状态区块里。
@MainActor
struct ProjectRAGSettingsView: View {
    @StateObject private var viewModel: ProjectRAGSettingsViewModel

    init(service: RAGService) {
        _viewModel = StateObject(wrappedValue: ProjectRAGSettingsViewModel(service: service))
    }

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                AppSettingSection(title: "上下文注入", titleAlignment: .leading) {
                    AppSettingToggleRow(
                        "自动注入代码上下文",
                        description: "提问时自动附上相关代码片段。关闭后仍可用 grep / search_code 工具手动检索。",
                        icon: "text.viewfinder",
                        isOn: $viewModel.autoInjectEnabled
                    )
                }
                AppSettingSection(title: "后台索引", titleAlignment: .leading) {
                    AppSettingToggleRow(
                        "暂停后台索引",
                        description: "暂停后不再自动建立或更新向量索引；grep / search_code 的实时搜索不受影响。",
                        icon: "pause.circle",
                        isOn: Binding(
                            get: { viewModel.indexingPaused },
                            set: { newValue in
                                Task { await viewModel.setIndexingPaused(newValue) }
                            }
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await viewModel.load() }
    }
}