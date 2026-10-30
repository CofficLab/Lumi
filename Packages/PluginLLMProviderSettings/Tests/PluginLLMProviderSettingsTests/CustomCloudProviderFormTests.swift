import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMProviderSettings

/// 「添加 / 编辑云端供应商」表单的输入解析与配置构造规则。
///
/// 这段逻辑原先埋在 `CustomCloudProviderEditor.save()` 的私有方法里，
/// 改坏了只有「点保存 → 看界面」才发现。抽成 `CustomCloudProviderForm` 后，
/// 解析规则、ID 生成、模型元数据继承都可以直接断言。
struct CustomCloudProviderFormTests {

    // MARK: - 模型 ID 解析

    @Test("模型 ID 按换行切分并保持顺序")
    func parsesModelIDsSeparatedByNewlines() {
        let form = CustomCloudProviderForm(modelIDsText: "gpt-4o\nclaude-3\nqwen-max")

        #expect(form.parsedModelIDs() == ["gpt-4o", "claude-3", "qwen-max"])
    }

    @Test("模型 ID 按逗号切分")
    func parsesModelIDsSeparatedByCommas() {
        let form = CustomCloudProviderForm(modelIDsText: "gpt-4o, claude-3,qwen-max")

        #expect(form.parsedModelIDs() == ["gpt-4o", "claude-3", "qwen-max"])
    }

    @Test("模型 ID 混合换行与逗号切分")
    func parsesModelIDsSeparatedByMixedDelimiters() {
        let form = CustomCloudProviderForm(modelIDsText: "gpt-4o,\nclaude-3, qwen-max")

        #expect(form.parsedModelIDs() == ["gpt-4o", "claude-3", "qwen-max"])
    }

    @Test("模型 ID 去掉首尾空白并丢弃空项")
    func trimsWhitespaceAndDropsEmptyModelIDs() {
        let form = CustomCloudProviderForm(modelIDsText: "  gpt-4o  \n\n , \tclaude-3\t \n  ")

        #expect(form.parsedModelIDs() == ["gpt-4o", "claude-3"])
    }

    @Test("模型 ID 解析保留重复项，交由校验层报错")
    func preservesDuplicateModelIDsForValidation() {
        let form = CustomCloudProviderForm(
            displayName: "团队网关",
            baseURL: "https://llm.example.com/v1",
            modelIDsText: "gpt-4o\ngpt-4o"
        )

        // 不在这里静默去重：用户填重了应该收到明确报错，
        // 而不是被改写成一份与输入不符的配置。
        #expect(form.parsedModelIDs() == ["gpt-4o", "gpt-4o"])
        #expect(throws: UserDefinedCloudProviderError.duplicateModel) {
            try form.makeConfiguration(existing: nil).validated()
        }
    }

    @Test("空白模型 ID 文本解析为空列表")
    func parsesEmptyModelIDTextAsEmptyList() {
        let form = CustomCloudProviderForm(modelIDsText: "   \n  \n ")

        #expect(form.parsedModelIDs().isEmpty)
    }

    // MARK: - 可保存判定

    @Test("名称为空或全是空白时不允许保存")
    func canSaveRequiresNonBlankDisplayName() {
        #expect(CustomCloudProviderForm(displayName: "").canSave == false)
        #expect(CustomCloudProviderForm(displayName: "   \n ").canSave == false)
        #expect(CustomCloudProviderForm(displayName: "团队网关").canSave == true)
    }

    // MARK: - 配置构造

    @Test("新增配置使用注入的 ID 生成器")
    func buildsConfigurationWithInjectedIdentifier() {
        let form = CustomCloudProviderForm(
            displayName: "团队网关",
            baseURL: "https://llm.example.com/v1",
            modelIDsText: "team-model"
        )

        let configuration = form.makeConfiguration(existing: nil, newID: { "user-fixed-id" })

        #expect(configuration.id == "user-fixed-id")
        #expect(configuration.displayName == "团队网关")
        #expect(configuration.baseURL == "https://llm.example.com/v1")
        #expect(configuration.models.map(\.id) == ["team-model"])
    }

    @Test("新增配置的默认 ID 带 user- 前缀且为小写 UUID")
    func buildsConfigurationWithGeneratedIdentifier() {
        let form = CustomCloudProviderForm(displayName: "网关", modelIDsText: "m")

        let configuration = form.makeConfiguration(existing: nil)

        #expect(configuration.id.hasPrefix("user-"))
        #expect(configuration.id == configuration.id.lowercased())
        #expect(configuration.id.count > "user-".count)
    }

    @Test("编辑既有供应商时沿用原 ID")
    func buildsConfigurationReusingExistingIdentifier() {
        let existing = UserDefinedCloudProviderConfiguration(
            id: "user-existing",
            displayName: "旧名字",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "m1",
            models: [UserDefinedCloudModel(id: "m1")]
        )
        let form = CustomCloudProviderForm(configuration: existing)

        let configuration = form.makeConfiguration(existing: existing)

        #expect(configuration.id == "user-existing")
    }

    @Test("配置构造把第一个模型设为默认模型")
    func buildsConfigurationDefaultingToFirstModel() {
        let form = CustomCloudProviderForm(
            displayName: "网关",
            modelIDsText: "m1\nm2\nm3"
        )

        let configuration = form.makeConfiguration(existing: nil)

        #expect(configuration.defaultModel == "m1")
    }

    @Test("配置构造保留选定的 API 协议格式")
    func buildsConfigurationPreservingAPIFormat() {
        let form = CustomCloudProviderForm(
            displayName: "网关",
            apiFormat: .anthropic,
            modelIDsText: "claude-3"
        )

        #expect(form.makeConfiguration(existing: nil).apiFormat == .anthropic)
    }

    @Test("编辑时按模型 ID 继承既有模型元数据")
    func buildsConfigurationInheritingExistingModelMetadata() {
        let existing = UserDefinedCloudProviderConfiguration(
            id: "user-existing",
            displayName: "旧名字",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "m1",
            models: [
                UserDefinedCloudModel(id: "m1", contextWindowSize: 128_000, supportsVision: true),
                UserDefinedCloudModel(id: "m2", contextWindowSize: 8_192)
            ]
        )
        // 用户改了名称，并删掉了 m2、新增 m3；m1 没动过。
        let form = CustomCloudProviderForm(
            displayName: "新名字",
            baseURL: "https://llm.example.com/v1",
            modelIDsText: "m1\nm3"
        )

        let configuration = form.makeConfiguration(existing: existing)

        #expect(configuration.displayName == "新名字")
        #expect(configuration.models.map(\.id) == ["m1", "m3"])
        // m1 继承上下文长度与视觉能力
        #expect(configuration.models[0].contextWindowSize == 128_000)
        #expect(configuration.models[0].supportsVision == true)
        // m3 是新模型，走默认值
        #expect(configuration.models[1].contextWindowSize == nil)
        #expect(configuration.models[1].supportsVision == false)
    }

    @Test("官网为空串时配置为 nil")
    func buildsConfigurationWithNilWebsiteWhenBlank() {
        let form = CustomCloudProviderForm(displayName: "网关", websiteURL: "   ")

        #expect(form.makeConfiguration(existing: nil).websiteURLString == nil)
    }

    @Test("官网去掉首尾空白后存储")
    func buildsConfigurationTrimmingWebsiteURL() {
        let form = CustomCloudProviderForm(displayName: "网关", websiteURL: "  https://llm.example.com  ")

        let configuration = form.makeConfiguration(existing: nil)

        // 不 trim 的话 `URL(string:)` 解析失败，官网链接会静默消失。
        #expect(configuration.websiteURLString == "https://llm.example.com")
        #expect(configuration.websiteURL == URL(string: "https://llm.example.com"))
    }

    // MARK: - 表单回填

    @Test("由既有配置回填表单时模型逐行展开")
    func formIsSeededFromExistingConfiguration() {
        let existing = UserDefinedCloudProviderConfiguration(
            id: "user-existing",
            displayName: "团队网关",
            description: "内部服务",
            baseURL: "https://llm.example.com/v1",
            apiFormat: .anthropic,
            defaultModel: "m1",
            models: [UserDefinedCloudModel(id: "m1"), UserDefinedCloudModel(id: "m2")],
            websiteURLString: "https://llm.example.com"
        )

        let form = CustomCloudProviderForm(configuration: existing)

        #expect(form.displayName == "团队网关")
        #expect(form.description == "内部服务")
        #expect(form.baseURL == "https://llm.example.com/v1")
        #expect(form.apiFormat == .anthropic)
        #expect(form.modelIDsText == "m1\nm2")
        #expect(form.websiteURL == "https://llm.example.com")
        #expect(form.canSave)
    }

    @Test("回填后再构造配置保持模型顺序与元数据")
    func reseededFormRebuildsEquivalentConfiguration() {
        let existing = UserDefinedCloudProviderConfiguration(
            id: "user-existing",
            displayName: "团队网关",
            baseURL: "https://llm.example.com/v1",
            defaultModel: "m1",
            models: [
                UserDefinedCloudModel(id: "m1", contextWindowSize: 128_000),
                UserDefinedCloudModel(id: "m2", contextWindowSize: 8_192)
            ]
        )

        let form = CustomCloudProviderForm(configuration: existing)
        let rebuilt = form.makeConfiguration(existing: existing)

        #expect(rebuilt.models == existing.models)
        #expect(rebuilt.defaultModel == "m1")
    }
}
