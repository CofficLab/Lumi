import Foundation
import KitLLM
import ProviderLLMManager

/// 「添加 / 编辑云端供应商」表单的草稿状态。
///
/// 把「用户输入 → 模型 ID 列表 → 可保存配置」这段纯逻辑从
/// `CustomCloudProviderEditor` 的 `save()` 里抽出来，收进一个值类型。
/// View 只负责渲染与提交，解析与构造规则则可以被单元测试直接覆盖——
/// 这段逻辑原先藏在 View 的私有方法里，既无法单测，
/// 也是「添加供应商」最容易出现回归（空名称、重复模型、URL 非法）的地方。
struct CustomCloudProviderForm: Equatable {
    /// 供应商名称（必填）。
    var displayName: String
    /// 描述（可选）。
    var description: String
    /// API Endpoint URL。
    var baseURL: String
    /// API 协议格式。
    var apiFormat: LLMProviderAPIFormat
    /// 模型 ID 原文，每行一个（也接受逗号分隔）。
    var modelIDsText: String
    /// 官网地址（可选）。
    var websiteURL: String

    init(
        displayName: String = "",
        description: String = "",
        baseURL: String = "",
        apiFormat: LLMProviderAPIFormat = .openAI,
        modelIDsText: String = "",
        websiteURL: String = ""
    ) {
        self.displayName = displayName
        self.description = description
        self.baseURL = baseURL
        self.apiFormat = apiFormat
        self.modelIDsText = modelIDsText
        self.websiteURL = websiteURL
    }

    /// 由既有配置回填（编辑场景）。
    init(configuration: UserDefinedCloudProviderConfiguration) {
        self.init(
            displayName: configuration.displayName,
            description: configuration.description,
            baseURL: configuration.baseURL,
            apiFormat: configuration.apiFormat,
            modelIDsText: configuration.models.map(\.id).joined(separator: "\n"),
            websiteURL: configuration.websiteURLString ?? ""
        )
    }

    /// 名称为空时不允许保存。
    ///
    /// 与 `UserDefinedCloudProviderConfiguration.validated()` 的
    /// `missingDisplayName` 判定保持同一口径（都按去空白后的结果判断）。
    var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 解析模型 ID 文本。
    ///
    /// 规则：换行或逗号分隔 → 去掉每项首尾空白 → 丢弃空项，**保留顺序与重复项**。
    ///
    /// - Note: 重复项不在这里去重。重复模型由
    ///   `UserDefinedCloudProviderConfiguration.validated()` 判为
    ///   `duplicateModel` 并在界面上报错，这样用户能看见自己填重了，
    ///   而不是被静默改写成一份与输入不符的配置。
    func parsedModelIDs() -> [String] {
        modelIDsText
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// 构造待保存的配置。
    ///
    /// - Parameters:
    ///   - existing: 被编辑的既有配置；为 `nil` 表示新增。
    ///   - newID: 新增时生成 ID 的工厂。默认生成 `user-<uuid>`；
    ///     显式注入便于测试断言。
    func makeConfiguration(
        existing: UserDefinedCloudProviderConfiguration?,
        newID: () -> String = { "user-\(UUID().uuidString.lowercased())" }
    ) -> UserDefinedCloudProviderConfiguration {
        let ids = parsedModelIDs()
        // 既有模型元数据（上下文长度 / 视觉 / 工具支持）在编辑时按 ID 继承，
        // 用户没动过的模型不应该因为改了个名字就丢掉能力标记。
        //
        // - Important: 用 `uniquingKeysWith` 而不是 `uniqueKeysWithValues`——
        //   后者遇到重复键会直接触发运行时崩溃。既有配置本应无重复，
        //   但这里不值得为「不可能发生」留一个 crash 点。
        let previousModels = Dictionary(
            (existing?.models ?? []).map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let models = ids.map { previousModels[$0] ?? UserDefinedCloudModel(id: $0) }
        let trimmedWebsite = websiteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return UserDefinedCloudProviderConfiguration(
            id: existing?.id ?? newID(),
            displayName: displayName,
            description: description,
            baseURL: baseURL,
            apiFormat: apiFormat,
            defaultModel: models.first?.id ?? "",
            models: models,
            // 空串归一成 nil；非空则存去空白后的值。
            //
            // - Note: 这里做 trim 是必要的：`UserDefinedCloudProviderConfiguration.websiteURL`
            //   用 `URL(string:)` 解析，带首尾空白的字符串会解析失败、
            //   官网链接静默消失。空判与存储必须用同一份去空白结果。
            websiteURLString: trimmedWebsite.isEmpty ? nil : trimmedWebsite
        )
    }
}
