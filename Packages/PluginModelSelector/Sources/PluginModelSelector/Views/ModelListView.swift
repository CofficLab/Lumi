import Foundation
import LumiUI
import ProviderLLMManager
import ProviderToast
import KitLLM
import SwiftUI

/// 模型能力筛选范围。
///
/// 基于模型 id / displayName 的启发式规则 + `LLMModelInfo` 能力元数据推断类别；
/// 供应商未声明能力元数据时（`modelInfo == nil`）仅做「语言模型」归类，
/// 避免因信息缺失把模型错误地筛掉。
enum ModelCategory: String, CaseIterable {
    /// 全部模型（不筛选）。
    case all
    /// 纯语言模型（非视觉、非语音、非图像类）。
    case language
    /// 视觉 / 多模态理解模型（支持视觉输入）。
    case vision
    /// 工具调用模型（Agent / Function Calling）。
    case tools
    /// 语音类模型（TTS / ASR / 对话音频）。
    case audio
    /// 图像生成类模型。
    case image

    var displayName: String {
        switch self {
        case .all: return LumiPluginLocalization.string("All", bundle: .module)
        case .language: return LumiPluginLocalization.string("Language Models", bundle: .module)
        case .vision: return LumiPluginLocalization.string("Vision Models", bundle: .module)
        case .tools: return LumiPluginLocalization.string("Tool Models", bundle: .module)
        case .audio: return LumiPluginLocalization.string("Audio Models", bundle: .module)
        case .image: return LumiPluginLocalization.string("Image Models", bundle: .module)
        }
    }

    /// 判断模型是否属于当前类别。
    ///
    /// - Parameters:
    ///   - model: 模型 id（兼容只持有 id 列表的调用方）。
    ///   - modelInfo: 模型能力元数据；供应商未声明时为 `nil`。
    /// - Returns: 是否命中该类别。
    func includes(
        model: String,
        modelInfo: LLMModelInfo?
    ) -> Bool {
        let isAudio = Self.isAudioModel(model, modelInfo: modelInfo)
        let isImage = Self.isImageModel(model, modelInfo: modelInfo)
        let supportsVision = modelInfo?.supportsVision ?? false

        switch self {
        case .all:
            return true
        case .language:
            return !isAudio && !isImage
        case .vision:
            return !isAudio && !isImage && supportsVision
        case .tools:
            return modelInfo?.supportsTools ?? false
        case .audio:
            return isAudio
        case .image:
            return isImage
        }
    }

    // MARK: - Heuristics

    /// 语音类模型：id 含 TTS / ASR / Audio 等关键词。
    static func isAudioModel(_ model: String, modelInfo: LLMModelInfo?) -> Bool {
        let name = model.lowercased()
        for keyword in ["tts", "asr", "audio", "realtime", "voice"] where name.contains(keyword) {
            return true
        }
        return false
    }

    /// 图像生成类模型：id 含 Image / Flux / Draw 等关键词，或供应商侧归类为图像。
    static func isImageModel(_ model: String, modelInfo: LLMModelInfo?) -> Bool {
        let name = model.lowercased()
        for keyword in ["image", "flux", "draw", "dall", "imagen", "seedream", "cogview"] where name.contains(keyword) {
            return true
        }
        return false
    }
}

/// 模型列表视图（由旧版 ModelSelectorPlugin 复刻）。
///
/// 显示指定供应商的模型列表，支持搜索、能力筛选和选择。
/// 数据源为内核 `LLMManaging`（经 `ObservableLLMProviderManagerBox` 订阅）。
struct ModelListView: View {
    @LumiTheme private var theme
    @ObservedObject var box: ObservableLLMProviderManagerBox
    let selectedProviderID: String?
    let initialModel: String?
    let toast: (any ToastProviding)?
    var onSelect: ((_ providerID: String, _ model: String) -> Void)? = nil

    @State private var searchText = ""
    @State private var selectedCategory: ModelCategory = .all

    /// 当前选中供应商的模型元数据字典（id → LLMModelInfo）
    private var selectedProviderModelInfos: [String: LLMModelInfo] {
        guard let providerID = selectedProviderID,
              let info = box.providerInfo(id: providerID)
        else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: info.models.map { ($0.id, $0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category filter
            ModelCategoryFilterBar(selectedCategory: $selectedCategory)

            AppDivider()

            // Search
            AppSearchBar(text: $searchText, placeholder: LocalizedStringKey(LumiPluginLocalization.string("Search models", bundle: .module)))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

            AppDivider()

            // Model items
            if let providerID = selectedProviderID {
                let models = box.models(for: providerID)
                let modelInfos = selectedProviderModelInfos
                let visibleModels = applyCategoryAndSearch(to: models, modelInfos: modelInfos)

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(visibleModels, id: \.self) { model in
                            let modelInfo = modelInfos[model]
                            let displayName = modelInfo?.displayName ?? model
                            let isSelected = model == initialModel

                            ModelListItem(
                                displayName: displayName,
                                model: model,
                                isSelected: isSelected,
                                modelInfo: modelInfo,
                                onSelect: {
                                    onSelect?(providerID, model)
                                    box.select(providerID: providerID, model: model)
                                    // 通过内核 Toast 能力通知用户模型已切换
                                    let providerDisplayName = box.providerInfo(id: providerID)?.displayName ?? providerID
                                    let modelDisplayName = modelInfo?.displayName ?? model
                                    toast?.show(
                                        LumiPluginLocalization.string("Switched to", bundle: .module),
                                        detail: "\(providerDisplayName) · \(modelDisplayName)",
                                        style: .success
                                    )
                                }
                            )
                        }
                    }
                    .padding(8)
                }
            } else {
                Spacer()
                Text(LumiPluginLocalization.string("Select a provider", bundle: .module))
                    .font(.appCallout)
                    .foregroundColor(theme.textTertiary)
                Spacer()
            }
        }
        .background(theme.background)
    }

    // MARK: - Filtering

    /// 类别筛选 + 搜索框文本过滤。
    private func applyCategoryAndSearch(
        to models: [String],
        modelInfos: [String: LLMModelInfo]
    ) -> [String] {
        models
            .filter { model in
                selectedCategory.includes(model: model, modelInfo: modelInfos[model])
            }
            .sorted { lhs, rhs in
                lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
            .filter { model in
                searchText.isEmpty
                    || model.localizedCaseInsensitiveContains(searchText)
                    || (modelInfos[model]?.displayName ?? model).localizedCaseInsensitiveContains(searchText)
            }
    }
}

/// 模型能力筛选栏：横向滚动的标签（全部 / 语言模型 / 视觉模型 / …）。
///
/// 样式对齐 `AppTag`，选中态使用主题色填充。
private struct ModelCategoryFilterBar: View {
    @LumiTheme private var theme

    @Binding var selectedCategory: ModelCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ModelCategory.allCases, id: \.self) { category in
                    filterTag(for: category)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(theme.surface)
    }

    @ViewBuilder
    private func filterTag(for category: ModelCategory) -> some View {
        let isSelected = selectedCategory == category

        Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 4) {
                Text(category.displayName)
                    .font(.appCaptionEmphasized)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(isSelected ? theme.primary.opacity(0.16) : theme.textSecondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .stroke(
                        isSelected ? theme.primary.opacity(0.4) : theme.appSubtleBorder,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
